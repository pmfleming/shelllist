import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui
import "BluetoothBattery.js" as BluetoothBattery
import "BluetoothFlow.js" as BluetoothFlow

Item {
    id: controller

    property bool uiActive: false
    property string currentWorkspaceId: ""
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    property bool detailsOpen: false
    property string detailsTab: "device"
    property var pendingConfirmationAction: null
    property bool scanRequested: false
    property var adapters: []
    property var audioDevices: []
    property var lastKnownBatteryByDevice: ({})
    property string audioStatus: ""
    property var obexCapabilities: ({})
    property var pairingPrompt: null
    property var incomingTransferPrompt: null
    property var activeOperation: null
    property var activeTransfer: null
    property var activeScan: null
    property bool trustAfterPair: true
    property string preferredAdapterKey: ""
    property string pairingInput: ""
    property string status: "Loading Bluetooth devices…"
    readonly property bool actionInFlight: backend.running || canCancelOperation || canCancelTransfer
    readonly property var filteredResults: results.visibleResults
    readonly property var filteredResultsModel: results.visibleModel
    readonly property var selectedResult: results.selected()
    readonly property var selectedDevice: selectedResult ? selectedResult.payload : ({})
    readonly property var detailActions: providers.actionsFor(selectedResult)
    readonly property alias selectionModel: results
    readonly property alias navigation: navigationModel
    readonly property var selectedAdapter: adapters.find(function (adapter) { return adapter.key === preferredAdapterKey; }) || adapters.find(function (adapter) { return adapter.key === selectedDevice.adapter_key; }) || adapters[0] || ({})
    readonly property var selectedAudio: audioDevices.find(function (audio) { return audio.device_key === selectedDevice.key; }) || ({})
    readonly property var selectedSink: selectedAudio.sink || ({})
    readonly property var selectedSource: selectedAudio.source || ({})
    readonly property var selectedAudioProfiles: selectedAudio.profiles || []
    readonly property var activeAudioProfile: selectedAudioProfiles.find(function (profile) { return profile.key === selectedAudio.active_profile_key; }) || ({})
    readonly property bool hasSelection: filteredResults.length > 0
    readonly property bool pairingPromptOpen: !!pairingPrompt
    readonly property bool incomingTransferPromptOpen: !!incomingTransferPrompt
    readonly property bool confirmationOpen: !!pendingConfirmationAction
    readonly property bool modalPromptOpen: pairingPromptOpen || incomingTransferPromptOpen || confirmationOpen
    readonly property bool canCancelTransfer: !!activeTransfer && !["complete", "cancelled", "error"].includes(activeTransfer.status)
    readonly property bool canCancelOperation: !!activeOperation && (activeOperation.state === "queued" || activeOperation.state === "running")
    readonly property bool powered: selectedAdapter.key ? !!selectedAdapter.powered : adapters.some(function (adapter) { return adapter.powered; })
    readonly property bool scanning: !!activeScan
    readonly property bool refreshInFlight: scanning
        || backend.isPending("snapshot")
        || backend.isPending("scan-start")
    readonly property int closedWindowWidth: Ui.Theme.popupClosedWidth
    readonly property int openWindowWidth: Ui.Theme.popupOpenWidth
    readonly property int surfaceWindowWidth: openWindowWidth
    readonly property int contentMargin: Ui.Theme.contentMargin
    readonly property int contentVerticalMargin: Ui.Theme.contentVerticalMargin
    readonly property int listPaneWidth: closedWindowWidth - 2 * contentMargin
    readonly property int detailsGapWidth: Ui.Theme.detailsGapWidth
    readonly property real detailsRenderCutoff: 0.025
    property real detailsExpansionProgress: detailsOpen ? 1 : 0
    readonly property real detailsPaintProgress: (!detailsOpen && detailsExpansionProgress <= detailsRenderCutoff) ? 0 : detailsExpansionProgress
    readonly property real detailsPaneFullWidth: openWindowWidth - closedWindowWidth - detailsGapWidth
    readonly property real detailsPaneWidth: detailsPaintProgress * detailsPaneFullWidth
    readonly property real detailsPaneGapWidth: detailsPaintProgress * detailsGapWidth
    readonly property bool detailsRendered: detailsOpen || detailsExpansionProgress > detailsRenderCutoff
    readonly property int currentWindowWidth: Math.round(closedWindowWidth + detailsPaintProgress * (openWindowWidth - closedWindowWidth))

    signal closeWindowRequested
    signal focusSearchRequested
    signal focusListTopRequested
    signal incomingTransferRequested

    function activateUi(workspaceId) {
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
        scanRequested = false;
        refresh();
        backend.refreshObex();
    }
    function deactivateUi() {
        if (pairingPromptOpen && pairingPrompt.response_required)
            backend.respondPairing(pairingPrompt.request_id, false, "");
        if (incomingTransferPromptOpen)
            backend.respondObex(incomingTransferPrompt.request_id, false);
        pairingPrompt = null;
        incomingTransferPrompt = null;
        pendingConfirmationAction = null;
        pairingInput = "";
        scanRequested = false;
        if (activeScan)
            backend.setScanning(false, activeScan.adapter_key);
        activeScan = null;
        uiActive = false;
    }
    function handleTransportFailure(message) {
        scanRequested = false;
        activeOperation = null;
        activeTransfer = null;
        activeScan = null;
        incomingTransferPrompt = null;
        status = message;
    }
    function refresh() {
        status = scanning ? "Scanning for Bluetooth devices…" : "Refreshing Bluetooth devices…";
        backend.refresh();
    }
    function applyObexSnapshot(capabilities) {
        obexCapabilities = capabilities || ({});
    }
    function applyAudioSnapshot(devices) {
        audioDevices = devices || [];
        audioStatus = "";
    }
    function devicesWithRememberedBattery(devices) {
        const cache = Object.assign({}, lastKnownBatteryByDevice);
        const observedKeys = ({});
        const enriched = (devices || []).map(function (device) {
            const key = device.key || "";
            if (key.length > 0)
                observedKeys[key] = true;
            const currentReports = BluetoothBattery.ordered(device.battery || []);
            if (currentReports.length > 0) {
                if (key.length > 0)
                    cache[key] = currentReports;
                return Object.assign({}, device, {
                    battery: currentReports,
                    battery_last_known: !device.connected
                });
            }
            const rememberedReports = key.length > 0 ? (cache[key] || []) : [];
            if (!device.connected && rememberedReports.length > 0) {
                console.info("shelllist bluetooth battery restored device_key=" + key
                    + " reports=" + rememberedReports.length);
                return Object.assign({}, device, {
                    battery: rememberedReports,
                    battery_last_known: true
                });
            }
            return Object.assign({}, device, {
                battery: currentReports,
                battery_last_known: false
            });
        });
        Object.keys(cache).forEach(function (key) {
            if (!observedKeys[key])
                delete cache[key];
        });
        lastKnownBatteryByDevice = cache;
        return enriched;
    }
    function applySnapshot(snapshot) {
        adapters = snapshot.adapters || [];
        preferredAdapterKey = BluetoothFlow.retainedAdapterKey(adapters, preferredAdapterKey);
        const devices = devicesWithRememberedBattery(snapshot.devices || []);
        results.replaceProviderResults(provider.providerId, provider.resultsForDevices(devices), false);
        if (BluetoothFlow.shouldStartScan(uiActive, powered, scanning, scanRequested)) {
            scanRequested = true;
            backend.setScanning(true, selectedAdapter.key);
        }
        status = BluetoothFlow.snapshotStatus(powered, scanning, filteredResults.length);
    }
    function statusForCompletedCall(id) {
        if (id === "power")
            return powered ? "Bluetooth turned on" : "Bluetooth turned off";
        if (id === "scan-start")
            return "Scanning for Bluetooth devices…";
        if (id === "scan-stop" || id.indexOf("cancel-scan-") === 0)
            return "Bluetooth scan stopped";
        if (id === "pairing-response")
            return "Pairing response sent";
        if (id === "obex-response")
            return status;
        if (id.indexOf("device-") === 0)
            return "Bluetooth device updated";
        return status;
    }
    function setPower() {
        status = powered ? "Turning Bluetooth off…" : "Turning Bluetooth on…";
        scanRequested = false;
        backend.setPowered(!powered, selectedAdapter.key);
    }
    function toggleScan() {
        status = scanning ? "Stopping Bluetooth scan…" : "Scanning for Bluetooth devices…";
        scanRequested = true;
        backend.setScanning(!scanning, selectedAdapter.key);
    }
    function scanCompletionStatus(scan) {
        const messages = {
            completed: filteredResults.length + " Bluetooth devices · scan complete",
            cancelled: "Bluetooth scan stopped",
            failed: (scan.error && scan.error.message) || "Bluetooth scan failed"
        };
        return messages[scan.state] || status;
    }
    function handleScanEvent(scan) {
        if (!scan || !scan.request_id)
            return;
        if (scan.state === "running") {
            activeScan = scan;
            if (scan.snapshot)
                applySnapshot(scan.snapshot);
            status = "Scanning for Bluetooth devices…";
            return;
        }
        if (activeScan && activeScan.request_id === scan.request_id)
            activeScan = null;
        if (scan.snapshot)
            applySnapshot(scan.snapshot);
        status = scanCompletionStatus(scan);
    }
    function sendFile(path) {
        if (!hasSelection || !path || actionInFlight || !obexCapabilities.outgoing_object_push)
            return false;
        status = "Starting file transfer to " + selectedDevice.name + "…";
        return backend.sendFile(selectedDevice.key, path);
    }
    function isTerminalTransfer(transfer) { return BluetoothFlow.isTerminalTransfer(transfer); }
    function completedTransferStatus(transfer) {
        if (transfer.status === "complete")
            return transfer.direction === "incoming" ? transfer.file_name + " saved in Downloads" : transfer.file_name + " sent";
        if (transfer.status === "cancelled")
            return "File transfer cancelled";
        return (transfer.error && transfer.error.message) || "File transfer failed";
    }
    function transferProgressStatus(transfer) {
        const percentage = transfer.size > 0 ? Math.floor(transfer.transferred * 100 / transfer.size) : 0;
        const verb = transfer.direction === "incoming" ? "Receiving " : "Sending ";
        return verb + transfer.file_name + (transfer.size > 0 ? " · " + percentage + "%" : "…");
    }
    function handleObexTransfer(transfer) {
        if (!transfer || !transfer.request_id)
            return;
        if (transfer.status === "awaiting-authorization") {
            activeTransfer = transfer;
            incomingTransferPrompt = transfer;
            status = "Incoming file transfer approval required";
            incomingTransferRequested();
            return;
        }
        if (incomingTransferPrompt && incomingTransferPrompt.request_id === transfer.request_id)
            incomingTransferPrompt = null;
        if (isTerminalTransfer(transfer)) {
            if (activeTransfer && activeTransfer.request_id === transfer.request_id)
                activeTransfer = null;
            status = completedTransferStatus(transfer);
            return;
        }
        activeTransfer = transfer;
        status = transferProgressStatus(transfer);
    }
    function respondIncomingTransfer(accept) {
        if (!incomingTransferPromptOpen)
            return false;
        const requestId = incomingTransferPrompt.request_id;
        incomingTransferPrompt = null;
        status = accept ? "Accepting incoming file…" : "Rejecting incoming file…";
        return backend.respondObex(requestId, accept);
    }
    function cancelActiveTransfer() {
        if (!canCancelTransfer)
            return false;
        status = "Cancelling file transfer…";
        return backend.cancelTransfer(activeTransfer.request_id);
    }
    function handleOperationAccepted(operation) {
        if (!activeOperation || activeOperation.request_id !== operation.request_id)
            activeOperation = operation;
    }
    function operationCompletionStatus(operation, deviceName) {
        if (operation.state === "completed")
            return deviceName + " updated";
        if (operation.state === "cancelled")
            return "Bluetooth operation cancelled";
        return (operation.error && operation.error.message) || "Bluetooth operation failed";
    }
    function handleOperationEvent(operation) {
        if (!operation || !operation.request_id)
            return;
        const device = filteredResults.find(function (result) { return result.id === operation.device_key; });
        const deviceName = device ? device.title : "Bluetooth device";
        if (BluetoothFlow.isActiveOperation(operation)) {
            activeOperation = operation;
            status = operation.operation.charAt(0).toUpperCase() + operation.operation.slice(1) + " " + deviceName + "…";
            return;
        }
        if (operation.snapshot)
            applySnapshot(operation.snapshot);
        if (activeOperation && activeOperation.request_id === operation.request_id)
            activeOperation = null;
        if (BluetoothFlow.operationEndsPairing(operation, pairingPrompt)) {
            pairingPrompt = null;
            pairingInput = "";
        }
        status = operationCompletionStatus(operation, deviceName);
    }
    function cancelActiveOperation() {
        if (!canCancelOperation)
            return false;
        status = "Cancelling Bluetooth operation…";
        return backend.cancelOperation(activeOperation.request_id);
    }
    function handlePairingEvent(event) {
        const transition = BluetoothFlow.pairingTransition(pairingPrompt, event);
        if (!transition.changed)
            return;
        pairingPrompt = transition.prompt;
        pairingInput = "";
        if (pairingPrompt)
            status = pairingPrompt.response_required ? "Pairing confirmation required" : "Complete pairing on the Bluetooth device";
        else if (event.data && event.data.reason === "timeout")
            status = "Bluetooth pairing request timed out";
    }
    function respondPairing(accept) {
        if (!pairingPromptOpen || !pairingPrompt.response_required)
            return false;
        const requestId = pairingPrompt.request_id;
        const value = pairingInput;
        pairingPrompt = null;
        pairingInput = "";
        return backend.respondPairing(requestId, accept, value);
    }
    function adapterOperation(operation, values) {
        if (!selectedAdapter.key || actionInFlight) {
            console.warn("shelllist bluetooth adapter operation rejected operation=" + operation
                + " adapter_key=" + (selectedAdapter.key || "") + " busy=" + actionInFlight);
            status = actionInFlight ? "Wait for the current Bluetooth action to finish…" : "No Bluetooth adapter is selected.";
            return false;
        }
        status = "Updating Bluetooth adapter…";
        const accepted = backend.adapterOperation(operation, selectedAdapter, values || ({}));
        if (!accepted) {
            console.error("shelllist bluetooth adapter operation rejected stage=dispatch operation=" + operation
                + " adapter_key=" + selectedAdapter.key);
            status = "Could not start Bluetooth adapter operation " + operation + ".";
        }
        return accepted;
    }
    function setAudioProfile(profile) {
        if (!hasSelection || !profile || !profile.key || !profile.available || actionInFlight)
            return false;
        status = "Switching Bluetooth audio to " + profile.label + "…";
        return backend.setAudioProfile(selectedDevice.key, profile.key);
    }
    function renameSelected(alias) {
        const value = (alias || "").trim();
        if (!hasSelection || value.length === 0 || value === selectedDevice.name || actionInFlight)
            return false;
        status = "Renaming " + selectedDevice.name + "…";
        return backend.deviceOperation("set-alias", selectedDevice, { alias: value });
    }
    function moveSelection(delta) { results.move(delta); }
    function cycleDetailsTab() {
        if (!detailsOpen || !hasSelection)
            return false;
        const tabs = ["device", "audio", "adapter"];
        const currentIndex = Math.max(0, tabs.indexOf(detailsTab));
        detailsTab = tabs[(currentIndex + 1) % tabs.length];
        return true;
    }
    function primarySelected() { return hasSelection && providers.execute(selectedResult, "", { workspaceId: currentWorkspaceId }); }
    function actionForId(id) { return detailActions.find(function (action) { return action.id === id; }) || null; }
    function triggerDetailAction(id) {
        if (!hasSelection)
            return false;
        const action = actionForId(id);
        if (!action || action.visible === false || action.enabled === false)
            return false;
        if (action.confirmation && action.confirmation.required) {
            pendingConfirmationAction = action;
            return true;
        }
        return providers.execute(selectedResult, id, { workspaceId: currentWorkspaceId });
    }
    function triggerAction(id) { return triggerDetailAction(id); }
    function cancelPendingConfirmation() { pendingConfirmationAction = null; }
    function confirmPendingAction() {
        if (!pendingConfirmationAction)
            return false;
        const actionId = pendingConfirmationAction.id;
        pendingConfirmationAction = null;
        return hasSelection && providers.execute(selectedResult, actionId, { workspaceId: currentWorkspaceId });
    }
    function executeDeviceAction(actionId, device) {
        if (actionInFlight)
            return false;
        const operation = ({ pair: "pair", connect: "connect", disconnect: "disconnect", forget: "remove" })[actionId];
        if (operation) {
            const actionLabel = actionId === "forget" ? "Forgetting" : (operation.charAt(0).toUpperCase() + operation.slice(1));
            status = actionLabel + " " + device.name + "…";
            return backend.deviceOperation(operation, device, operation === "pair" ? { trust_after_pair: trustAfterPair } : {});
        }
        if (actionId === "trusted")
            return backend.deviceOperation("set-trusted", device, { trusted: !device.trusted });
        if (actionId === "wake")
            return backend.deviceOperation("set-wake-allowed", device, { wake_allowed: !device.wake_allowed });
        if (actionId === "blocked")
            return backend.deviceOperation("set-blocked", device, { blocked: !device.blocked });
        return false;
    }

    onModalPromptOpenChanged: if (!modalPromptOpen) Qt.callLater(focusSearchRequested)
    onSelectedResultChanged: pendingConfirmationAction = null

    Behavior on detailsExpansionProgress { enabled: !Ui.Theme.noAnimations; NumberAnimation { duration: Ui.Theme.animationNormal; easing.type: Ui.Theme.easingGentle } }
    Ui.ResultNavigation { id: navigationModel; controller: controller; blocked: controller.modalPromptOpen }
    Core.ProviderRegistry {
        id: providers
        BluetoothProvider { id: provider; controller: controller }
    }
    Core.ResultStore { id: results; registry: providers }
    BluetoothBackend { id: backend; controller: controller }
}
