pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Bluetooth as Bt

// Only launched by bt-daemon's private fake-backend fixture. Operation delivery
// is deliberately omitted from this consumer's subscription: status must repair
// quiet terminal loss through the production shared socket path, never replay.
ShellRoot {
    id: root
    readonly property bool privateProbe: Quickshell.env("SOCKET_PROBE_MODE") === "bt-operations"
        && Quickshell.env("SHELLLIST_BT_SOCKET") === "1"
    property bool ownerAlive: true
    readonly property var controller: controllerLoader.item
    readonly property var peer: peerLoader.item
    property var backend: null
    property var peerBackend: null
    property bool peerObservedActive: false
    property bool peerObservedTerminal: false
    property bool peerReadAfterRelease: false
    property string phase: "initialize"
    property int ticks: 0
    property int statusReads: 0
    property int terminalReads: 0
    property string operationId: ""
    Component {
        id: probeController
        Bt.BluetoothController {
            Component.onCompleted: {
                // Both consumers configure observation before the asynchronous
                // native connection becomes ready. A late-attached default
                // operation subscription could deliver the withheld terminal.
                const backend = children.find(child => child.objectName === "bluetoothBackend");
                backend.streams = ["bluetooth.changed"];
            }
        }
    }
    Loader {
        id: controllerLoader
        active: root.privateProbe && root.ownerAlive
        sourceComponent: probeController
    }
    Loader {
        id: peerLoader
        active: root.privateProbe
        sourceComponent: probeController
    }
    Component.onCompleted: if (!privateProbe) fail("private producer harness required")
    Connections {
        target: root.backend
        function onResponseReceived(id: string, envelope: var, transportError: string): void {
            if (!id.startsWith("operation-status-") || transportError)
                return;
            const operation = envelope?.data?.operation_status;
            if (operation) {
                root.statusReads += 1;
                if (operation.state === "cancelled")
                    root.terminalReads += 1;
            }
        }
    }
    Connections {
        target: root.peerBackend
        function onResponseReceived(id: string, envelope: var, transportError: string): void {
            if (transportError || !envelope?.ok)
                return;
            const operations = envelope.data?.requests?.operations;
            if (operations) {
                if (operations.active.some(operation => operation.request_id === root.operationId))
                    root.peerObservedActive = true;
                if (operations.recent.some(operation => operation.request_id === root.operationId))
                    root.peerObservedTerminal = true;
            }
            if (!root.ownerAlive && id === "snapshot")
                root.peerReadAfterRelease = true;
        }
    }
    function fail(message: string): void {
        console.error("SOCKET_PROBE_FAIL bt-operations " + message);
        Qt.exit(1);
    }
    Timer {
        interval: 25
        running: root.privateProbe
        repeat: true
        onTriggered: {
            root.ticks += 1;
            if (root.ticks > 480) {
                root.fail("bounded lifecycle deadline");
                return;
            }
            // Each named phase owns one transition; waiting never resubmits an
            // effect, and status evidence alone permits cancellation/retirement.
            switch (root.phase) {
            case "initialize":
                if (!root.controller)
                    return;
                root.backend = root.controller.children.find(child => child.objectName === "bluetoothBackend");
                if (!root.backend)
                    return;
                if (!root.peer)
                    return;
                root.peerBackend = root.peer.children.find(child => child.objectName === "bluetoothBackend");
                if (!root.peerBackend)
                    return;
                root.phase = "admit";
                break;
            case "admit":
                if (root.ticks <= 12 || !root.backend.ready || !root.controller.backendAvailable
                        || root.backend.foregroundRequestRunning)
                    return;
                root.controller.handlePairingEvent({event: "requested", data: {request_id: "private-fixture-prompt",
                    device_key: "lifecycle-fixture-device", kind: "pin-code", response_required: true}});
                root.controller.pairingInput = "private-fixture-draft";
                if (!root.backend.deviceOperation("connect", {key: "lifecycle-fixture-device"}, {}))
                    root.fail("effect admission failed");
                root.phase = "cancel";
                break;
            case "cancel":
                if (root.statusReads <= 0)
                    return;
                const operation = root.controller.operationForDevice("lifecycle-fixture-device");
                if (!operation || !Number.isSafeInteger(operation.revision)) {
                    root.fail("owned active status missing");
                    return;
                }
                root.operationId = operation.request_id;
                root.phase = "peer-initialize";
                break;
            case "peer-initialize":
                if (!root.peerBackend.ready || root.peerBackend.foregroundRequestRunning)
                    return;
                if (!root.peerBackend.recoverRequests()) {
                    root.fail("peer aggregate read failed");
                    return;
                }
                root.phase = "peer-observe";
                break;
            case "peer-observe":
                if (!root.peerObservedActive)
                    return;
                if (root.peerBackend.sharedConsumerId === root.backend.sharedConsumerId
                        || Object.keys(root.peerBackend.operations).length !== 0
                        || root.peer.deviceBusy("lifecycle-fixture-device")
                        || root.peerBackend.cancelOperation(root.operationId)) {
                    root.fail("shared-owner aggregate granted peer operation authority");
                    return;
                }
                if (!root.backend.cancelOperation(root.operationId))
                    root.fail("owned cancellation failed");
                root.phase = "recover";
                break;
            case "recover":
                if (root.controller.deviceBusy("lifecycle-fixture-device"))
                    return;
                if (root.statusReads < 2 || root.terminalReads !== 1 || !root.backend.finishedOperations[root.operationId]) {
                    root.fail("terminal was not recovered by owned status");
                    return;
                }
                if (root.controller.pairingPrompt?.request_id !== "private-fixture-prompt"
                        || root.controller.pairingInput !== "private-fixture-draft") {
                    root.fail("operation recovery changed unrelated prompt authority/draft");
                    return;
                }
                // Releasing this consumer must not retire the shared owner or
                // grant its acknowledged operation to the surviving consumer.
                root.ownerAlive = false;
                root.phase = "peer-read";
                break;
            case "peer-read":
                if (root.peerBackend.foregroundRequestRunning)
                    return;
                if (!root.peerBackend.refresh() || !root.peerBackend.recoverRequests()) {
                    root.fail("healthy peer read after consumer release failed");
                    return;
                }
                root.phase = "peer-terminal";
                break;
            case "peer-terminal":
                if (!root.peerReadAfterRelease || !root.peerObservedTerminal)
                    return;
                if (!root.peerBackend.ready || Object.keys(root.peerBackend.operations).length !== 0
                        || root.peerBackend.finishedOperations[root.operationId]
                        || root.peerBackend.cancelOperation(root.operationId)) {
                    root.fail("peer terminal history changed local operation authority");
                    return;
                }
                console.log("SOCKET_PROBE_PASS bt-operations shared-owner-active-terminal-and-peer-release");
                Qt.quit();
                break;
            }
        }
    }
}
