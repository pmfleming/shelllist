pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Wifi as Wifi
import Shelllist.Io as Io

// Launch only through nm-daemon's private scripted native harness. One explicit
// synthetic connect is admitted; the fixture drops terminal delivery locally to
// qualify read-only recovery through the real socket and production controller.
ShellRoot {
    id: root
    property bool started: false
    property bool terminalDropped: false
    property int statusReads: 0
    property int connectCalls: 0
    property bool recoveredTerminal: false

    function fail(reason) {
        console.error("NM_CONNECT_RECOVERY_FAIL " + reason);
        Qt.exit(1);
    }
    Wifi.WifiController {
        id: controller
        prompt: Wifi.WifiPromptController {}
        statusMonitorActive: true
        providerRankedResults: true // No search helper is needed by this outcome-only fixture.
    }
    QtObject {
        id: lossFixture
        function sending(id, method, params) {
            if (method === "wifi.connectTarget")
                root.connectCalls++;
            if (method === "operation.status")
                root.statusReads++;
            return params;
        }
        function received(id, envelope, error) {
            if (id.startsWith("connection-status") && !error) {
                const result = envelope?.data?.result;
                root.recoveredTerminal = result?.status === "finished" && result?.event?.event === "succeeded"
                    && result.operation_revision === result.event.operation_revision;
            }
            return envelope;
        }
        function observe(event) {
            if (event.stream === "wifi.connect" && ["succeeded", "failed", "cancelled"].includes(event.event)) {
                root.terminalDropped = true;
                return false;
            }
            return true;
        }
        function sendFailed(id) {}
        function reset(message) {}
    }
    Timer {
        interval: 30
        running: true
        repeat: true
        onTriggered: {
            if (!root.started && controller.backend.ready) {
                root.started = true;
                controller.backend.requestPolicy = lossFixture;
                const target = JSON.parse(Quickshell.env("SHELLLIST_NM_FIXTURE_TARGET"));
                controller.connection.run({target: target, remember: false}, "Private fixture");
                return;
            }
            if (root.terminalDropped && root.statusReads === 0 && controller.connection.requestId)
                controller.connection.checkStatus(false);
            if (!root.terminalDropped || root.statusReads < 1 || controller.connection.running)
                return;
            const session = Io.DaemonSessions.sessions["nm-daemon"];
            if (!session || !session.client.useSocket || !session.client.transportBackend.endpoint.connected
                    || root.connectCalls !== 1 || controller.connection.recoveryId
                    || controller.prompt.open || controller.prompt.credentialOpen) {
                root.fail("recovery lost native owner/guard or replayed connection/prompt");
                return;
            }
            if (!root.recoveredTerminal) {
                root.fail("missing authoritative recovered outcome");
                return;
            }
            console.log("NM_CONNECT_RECOVERY_PASS native-quiet-terminal-status");
            Qt.quit();
        }
    }
    Timer {
        interval: 10000
        running: true
        onTriggered: root.fail("native recovery timed out")
    }
}
