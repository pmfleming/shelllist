pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Io as Io
import Shelllist.Wifi as Wifi

// Private producer harness only. Its scripted NM changes current link facts
// after BASELINE without emitting a status event; recovery performs reads only.
ShellRoot {
    id: probe
    property int ticks: 0
    property bool baseline: false
    property bool peerRead: false
    property bool recoveredByRead: false
    property int statusReads: 0
    function fail(message) {
        console.error("NM_STATUS_RECOVERY_FAIL " + message);
        Qt.exit(1);
    }
    Wifi.WifiController {
        id: wifi
        statusMonitorActive: true
        providerRankedResults: true
        prompt: Wifi.WifiPromptController {}
        Component.onCompleted: backend.requestPolicy = lossFixture
        onActiveStatusChanged: {
            if (!activeStatus)
                return;
            if (!probe.baseline && !activeStatus.active) {
                probe.baseline = true;
                console.log("NM_STATUS_RECOVERY_BASELINE");
            }
        }
    }
    QtObject {
        id: lossFixture
        function sending(id, method, params) {
            if (method !== "wifi.status")
                throw new Error("status fixture attempted a non-status call");
            probe.statusReads++;
            return params;
        }
        function received(id, envelope, error) {
            if (!error && envelope?.data?.status?.active === true)
                probe.recoveredByRead = true;
            return envelope;
        }
        // Suppress watch delivery locally even if startup refresh overlaps the
        // source change. Success must come from a native status read, not a push.
        function observe(event) { return event.stream !== "wifi.status"; }
        function sendFailed(id) {}
        function reset(message) {}
    }
    Io.DaemonBackend {
        id: peer
        daemonName: "nm-daemon"
        expectedProtocol: "nm-api"
        expectedVersion: 2
        streams: ["wifi.secret"]
        active: true
        onTransportReady: call("peer-read", "wifi.status", {})
        onResponseReceived: function (id, envelope, error) {
            if (error || !envelope.ok) {
                probe.fail("healthy peer read failed");
                return;
            }
            probe.peerRead = true;
        }
        onTransportFailed: probe.fail("healthy peer disconnected")
    }
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (++probe.ticks > 60) {
                probe.fail("bounded quiet status recovery expired");
                return;
            }
            if (!probe.baseline)
                return;
            if (wifi.activeStatus && wifi.activeStatus.active && probe.peerRead) {
                const session = Io.DaemonSessions.sessions["nm-daemon"];
                if (wifi.backend.statusCursor.revision < 2 || !peer.ready
                        || !probe.recoveredByRead || probe.statusReads < 1 || !session
                        || !session.client.useSocket || !session.client.transportBackend.endpoint.connected) {
                    probe.fail("status identity or peer not retained");
                    return;
                }
                console.log("NM_STATUS_RECOVERY_PASS native-quiet-status-read");
                Qt.quit();
                return;
            }
            wifi.backend.recoverStatus();
        }
    }
}
