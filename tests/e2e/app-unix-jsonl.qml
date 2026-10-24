pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Io as Io

// Only launched by app-daemon's private process fixture. No user applications.
ShellRoot {
    id: root
    property int reads: 0
    property int baselines: 0
    property bool renewed: false
    property string subscription: ""
    function fail(message) { console.error("APP_SOCKET_PROBE_FAIL " + message); Qt.exit(1); }
    function progress() {
        if (reads < 8 || baselines < 1)
            return;
        const session = Io.DaemonSessions.sessions["app-daemon"];
        if (!session.client.useSocket || !session.client.transportBackend.endpoint.connected) {
            fail("not using native socket");
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
        console.log("APP_SOCKET_PROBE_PASS reads-and-renewal");
        Qt.quit();
    }
    Io.DaemonBackend {
        id: backend
        daemonName: "app-daemon"
        expectedProtocol: "app-api"
        expectedVersion: 2
        active: true
        streams: ["applications.changed", "applications.operation"]
        onTransportReady: call("read", "applications.query", {limit: 1000})
        onResponseReceived: function(id, envelope, error) {
            if (id !== "read")
                return;
            if (error || !envelope?.ok || !Array.isArray(envelope.data?.applications?.applications)
                    || envelope.data.applications.applications.length < 1) {
                root.fail("invalid catalog read");
                return;
            }
            root.reads++;
            if (root.reads < 8)
                call("read", "applications.query", {limit: 1000});
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
    Timer { interval: 15000; running: true; onTriggered: root.fail("deadline exceeded") }
}
