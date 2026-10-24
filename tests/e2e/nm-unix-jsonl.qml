pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Io as Io

// Only the isolated NM Rust probe may launch this: real Quickshell plugins,
// private runtime/bus, scripted NetworkManager, no host service or hardware.
ShellRoot {
    id: root
    property int reads: 0
    property int baselines: 0
    property int peerSubscriptions: 0
    property bool renewing: false
    property string firstSubscription: ""
    property string firstEpoch: ""
    property string peerSubscription: ""

    function fail(reason) {
        console.error("NM_SOCKET_PROBE_FAIL " + reason);
        Qt.exit(1);
    }
    function progress() {
        if (root.reads < 8 || root.baselines < 1 || root.peerSubscriptions < 1)
            return;
        const session = Io.DaemonSessions.sessions["nm-daemon"];
        if (!session || !session.client.useSocket || !session.client.transportBackend.endpoint.connected) {
            root.fail("not using the native socket opt-in");
            return;
        }
        if (!root.renewing) {
            root.renewing = true;
            if (!network.renewBaseSubscription())
                root.fail("network renewal was not admitted");
            return;
        }
        if (root.baselines < 2)
            return;
        if (root.peerSubscriptions !== 1 || session.consumers[peer.sharedConsumerId].baseSubscriptionId !== root.peerSubscription) {
            root.fail("network renewal retired the secret observer");
            return;
        }
        console.log("NM_SOCKET_PROBE_PASS native-shared-session-renewal");
        Qt.quit();
    }
    Io.DaemonBackend {
        id: network
        daemonName: "nm-daemon"
        expectedProtocol: "nm-api"
        expectedVersion: 2
        active: true
        streams: ["wifi.networks"]
        onTransportReady: call("read", "network.connectivity", {})
        onResponseReceived: function(id, envelope, error) {
            if (id !== "read")
                return;
            if (error || !envelope || !envelope.ok || !envelope.data.connectivity) {
                root.fail("invalid native read response");
                return;
            }
            root.reads++;
            if (root.reads < 8)
                call("read", "network.connectivity", {});
            root.progress();
        }
        onEventReceived: function(event) {
            if (event.stream !== "wifi.networks" || event.event !== "changed")
                return;
            const data = event.data;
            if (!data.initial || data.base_revision !== 0 || data.revision !== 1 || !data.epoch || !Array.isArray(data.added)) {
                root.fail("missing authoritative native baseline");
                return;
            }
            root.baselines++;
            if (root.baselines === 1) {
                root.firstSubscription = event.subscription_id;
                root.firstEpoch = data.epoch;
            } else if (!root.renewing || event.subscription_id === root.firstSubscription || data.epoch === root.firstEpoch) {
                root.fail("renewal reused an old delta chain");
                return;
            }
            root.progress();
        }
        onTransportFailed: function(message) { root.fail(message); }
        onSendFailed: function(id, message) { root.fail(id + ": " + message); }
    }
    Io.DaemonBackend {
        id: peer
        daemonName: "nm-daemon"
        expectedProtocol: "nm-api"
        expectedVersion: 2
        active: true
        streams: ["wifi.secret"]
        onEventReceived: function(event) {
            if (event.event === "subscribed") {
                root.peerSubscriptions++;
                root.peerSubscription = event.subscription_id;
                root.progress();
            }
        }
        onTransportFailed: function(message) { root.fail(message); }
        onSendFailed: function(id, message) { root.fail(id + ": " + message); }
    }
    Timer {
        interval: 10000
        running: true
        onTriggered: root.fail("native probe timed out")
    }
}
