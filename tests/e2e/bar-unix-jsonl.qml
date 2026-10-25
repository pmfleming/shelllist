pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Io as Io

// Launched only by the producer's private, read-only fixture; no host monitors.
ShellRoot {
    id: root
    readonly property bool privateProbe: Quickshell.env("SHELLLIST_PRIVATE_BAR_PROBE") === "1"
    property int reads: 0
    property int phase: 0
    property int audio: -1
    property int battery: -1
    property string mainSubscription: ""
    property string peerSubscription: ""
    property var sharedClient: null
    function fail(message) { console.error("BAR_SOCKET_PROBE_FAIL " + message); Qt.exit(1); }
    function stamped(backend, stream) {
        const cursor = backend.requestPolicy.cursor(stream);
        return cursor.epoch.length > 0 && cursor.revision > 0 && !backend.requestPolicy.error;
    }
    function progress() {
        const session = Io.DaemonSessions.sessions["bar-daemon"];
        if (!session || !peer.sharedConsumerId)
            return;
        const observer = session.consumers[peer.sharedConsumerId];
        if (!observer?.baseSubscriptionId)
            return;
        if (phase === 0) {
            const main = primary.item;
            if (!main || reads !== 8 || audio !== 43 || battery !== 71)
                return;
            const subscription = session.consumers[main.sharedConsumerId]?.baseSubscriptionId;
            if (!subscription || !stamped(main, "audio.changed") || !stamped(peer, "battery.changed"))
                return;
            if (!session.client.useSocket || !session.client.transportBackend.endpoint.connected
                    || Object.keys(Io.DaemonSessions.sessions).length !== 1 || Object.keys(session.consumers).length !== 2) {
                fail("not one native shared connection with two consumers");
                return;
            }
            mainSubscription = subscription;
            peerSubscription = observer.baseSubscriptionId;
            sharedClient = session.client;
            phase = 1;
            if (!main.renewBaseSubscription()) fail("renewal rejected");
        } else if (phase === 1) {
            const subscription = session.consumers[primary.item.sharedConsumerId]?.baseSubscriptionId;
            if (!subscription || subscription === mainSubscription)
                return;
            if (observer.baseSubscriptionId !== peerSubscription) {
                fail("renewal replaced peer subscription");
                return;
            }
            phase = 2;
            primary.active = false; // Destroy one real consumer, not the shared transport.
        } else if (phase === 2) {
            if (Object.keys(session.consumers).length !== 1)
                return;
            if (session.client !== sharedClient || !sharedClient.transportBackend.endpoint.connected
                    || observer.baseSubscriptionId !== peerSubscription) {
                fail("consumer release retired its peer/connection");
                return;
            }
            phase = 3;
            if (!peer.snapshotRequest("peer-final", ["battery.changed", "workarea.changed"]))
                fail("surviving peer read rejected");
        }
    }
    Loader {
        id: primary
        active: root.privateProbe
        sourceComponent: Io.BarDaemonBackend {
            daemonName: "bar-daemon"
            expectedProtocol: "bar-api"
            expectedVersion: 2
            streams: ["audio.changed", "workarea.changed"]
            active: true
            onTransportReady: snapshotRequest("read", ["audio.changed", "workarea.changed"])
            onResponseReceived: function(id, envelope, error) {
                if (id !== "read" || error || !envelope?.ok || !envelope.data?.snapshot?.audio) {
                    root.fail("invalid main read: " + error);
                    return;
                }
                root.audio = envelope.data.snapshot.audio.volume_percent;
                root.reads++;
                if (root.reads < 8 && !snapshotRequest("read", ["audio.changed", "workarea.changed"]))
                    root.fail("next read rejected");
                root.progress();
            }
            onEventReceived: function(event) {
                if (event.stream === "audio.changed") root.audio = event.data.volume_percent;
                root.progress();
            }
            onTransportFailed: function(message) { root.fail(message); }
            onSendFailed: function(id, message) { root.fail(id + ": " + message); }
        }
    }
    Io.BarDaemonBackend {
        id: peer
        daemonName: "bar-daemon"
        expectedProtocol: "bar-api"
        expectedVersion: 2
        streams: ["battery.changed", "workarea.changed"]
        active: root.privateProbe
        onEventReceived: function(event) {
            if (event.stream === "battery.changed") root.battery = event.data.percentage;
            root.progress();
        }
        onResponseReceived: function(id, envelope, error) {
            if (root.phase !== 3 || id !== "peer-final" || error || !envelope?.ok
                    || envelope.data?.snapshot?.battery?.percentage !== 71
                    || !envelope.data?.snapshot?.workarea || !root.stamped(peer, "battery.changed")) {
                root.fail("surviving peer projection invalid: " + error);
                return;
            }
            root.phase = 4;
            console.log("BAR_SOCKET_PROBE_PASS reads-publication-renewal-peer-release");
            Qt.quit();
        }
        onTransportFailed: function(message) { root.fail(message); }
        onSendFailed: function(id, message) { root.fail(id + ": " + message); }
    }
    Timer { interval: 20; repeat: true; running: root.privateProbe; onTriggered: root.progress() }
    Timer { interval: 15000; running: root.privateProbe; onTriggered: root.fail("deadline phase=" + root.phase + " reads=" + root.reads + " audio=" + root.audio) }
    Component.onCompleted: { if (!privateProbe) fail("private producer harness required"); }
}
