pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Io as Io
import Shelllist.Launcher as Apps

// Only launched by app-daemon's private process fixture. No user applications.
ShellRoot {
    id: root
    property int reads: 0
    property int baselines: 0
    property bool renewed: false
    property string subscription: ""
    readonly property int payloadBytes: Number(Quickshell.env("APP_SOCKET_PROBE_BYTES") || "0")
    property bool payloadReceived: payloadBytes === 0
    property bool healthyReadRequested: false
    property bool healthyReadReceived: false
    function query() { return payloadBytes ? {query: "ok.desktop", limit: 1} : {limit: 1000}; }
    function acceptPayload(envelope: var, error: string): void {
        if (payloadBackend.responseError(envelope, error, "large read failed")) {
            fail("large response rejected");
            return;
        }
        const page = envelope.data?.applications;
        const row = page?.applications?.[0];
        const comment = row?.comment;
        const units = Math.floor(payloadBytes / 6);
        const tail = payloadBytes % 6;
        if (page?.generation !== 19 || !Array.isArray(page.applications) || page.applications.length !== 1 || row?.id !== "large.desktop"
                || typeof comment !== "string" || comment.length !== units * 3 + tail) {
            fail("large identity/length mismatch");
            return;
        }
        // Validate every UTF-16 unit against the producer's UTF-8 fixture without
        // stringifying, rendering, retaining or logging the large response.
        for (let i = 0; i < units * 3; i += 3) {
            if (comment.charCodeAt(i) !== 0xe9 || comment.charCodeAt(i + 1) !== 0xd83e
                    || comment.charCodeAt(i + 2) !== 0xdd80) {
                fail("large UTF-8 content mismatch");
                return;
            }
        }
        if (comment.slice(units * 3) !== "x".repeat(tail)) {
            fail("large UTF-8 tail mismatch");
            return;
        }
        payloadReceived = true;
        progress();
    }
    function fail(message) { console.error("APP_SOCKET_PROBE_FAIL " + message); Qt.exit(1); }
    function progress() {
        if (reads < 8 || baselines < 1 || !payloadReceived)
            return;
        const session = Io.DaemonSessions.sessions["app-daemon"];
        if (!session.client.useSocket || !session.client.transportBackend.endpoint.connected) {
            fail("not using native socket");
            return;
        }
        if (payloadBytes > 0 && (backend.sharedConsumerId === payloadBackend.sharedConsumerId
                || !session.consumers[backend.sharedConsumerId] || !session.consumers[payloadBackend.sharedConsumerId])) {
            fail("large/healthy consumers not independently routed");
            return;
        }
        if (!renewed) {
            renewed = true;
            if (!backend.renewBaseSubscription())
                fail("subscription renewal rejected");
            return;
        }
        if (baselines < 2)
            return;
        if (!healthyReadRequested) {
            healthyReadRequested = true;
            backend.call("healthy", "applications.query", query());
            return;
        }
        if (!healthyReadReceived)
            return;
        console.log(payloadBytes ? "APP_SOCKET_PROBE_PASS large-utf8-and-healthy-peer"
                                 : "APP_SOCKET_PROBE_PASS reads-and-renewal");
        Qt.quit();
    }
    Io.DaemonBackend {
        id: backend
        daemonName: "app-daemon"
        expectedProtocol: Apps.AppApi.protocol
        expectedVersion: Apps.AppApi.version
        active: true
        validateRequest: Apps.AppApi.requestError
        validateEvent: Apps.AppApi.eventError
        streams: ["applications.changed", "applications.operation"]
        onTransportReady: call("read", "applications.query", root.query())
        onResponseReceived: function(id, envelope, error) {
            if (id !== "read" && id !== "healthy")
                return;
            if (responseError(envelope, error, "catalog read failed") || !Array.isArray(envelope?.data?.applications?.applications)
                    || envelope.data.applications.applications.length < 1
                    || (root.payloadBytes > 0 && (envelope.data.applications.applications.length !== 1
                        || envelope.data.applications.applications[0].id !== "ok.desktop"))) {
                root.fail("invalid catalog read");
                return;
            }
            if (id === "healthy")
                root.healthyReadReceived = true;
            else
                root.reads++;
            if (id === "read" && root.reads < 8)
                call("read", "applications.query", root.query());
            root.progress();
        }
        onEventReceived: function(event) {
            if (event.stream !== "applications.changed" || event.event !== "subscribed")
                return;
            if (event.subscription_id === root.subscription) {
                root.fail("renewal reused subscription");
                return;
            }
            root.subscription = event.subscription_id;
            root.baselines++;
            root.progress();
        }
        onTransportFailed: function(message) { root.fail(message); }
        onSendFailed: function(id, message) { root.fail(id + ": " + message); }
    }
    Io.DaemonBackend {
        id: payloadBackend
        daemonName: "app-daemon"
        expectedProtocol: Apps.AppApi.protocol
        expectedVersion: Apps.AppApi.version
        active: root.payloadBytes > 0
        validateRequest: Apps.AppApi.requestError
        validateEvent: Apps.AppApi.eventError
        // Same local ID as the healthy consumer deliberately exercises routing.
        onTransportReady: {
            if (active)
                call("read", "applications.query", {query: "large.desktop", limit: 1, generation: 19});
        }
        onResponseReceived: function(id, envelope, error) {
            if (id !== "read") {
                root.fail("large response route mismatch");
                return;
            }
            root.acceptPayload(envelope, error);
        }
        onTransportFailed: function(message) { root.fail(message); }
        onSendFailed: function(id, message) { root.fail(id + ": " + message); }
    }
    Timer { interval: 15000; running: true; onTriggered: root.fail("deadline exceeded") }
}
