import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "BluetoothBattery.js" as BluetoothBattery
import "BluetoothFlow.js" as BluetoothFlow

Ui.ChooserController {
    id: bluetoothController
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    property string detailsTab: "device"
    property var pendingConfirmationAction
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
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
    readonly property bool actionInFlight: backend.running || canCancelOperation || canCancelTransfer || screenshotInFlight
    readonly property var filteredResults: results.visibleResults
    readonly property var filteredResultsModel: results.visibleModel
    readonly property var selectedResult: results.selected()
    readonly property var selectedDevice: selectedResult ? selectedResult.payload : ({})
    navigationBlocked: modalPromptOpen
    readonly property var selectedAdapter: adapters.find(function (adapter) { return adapter.key === preferredAdapterKey; }) || adapters.find(function (adapter) { return adapter.key === selectedDevice.adapter_key; }) || adapters[0] || ({})
    readonly property var selectedAudio: audioDevices.find(function (audio) { return audio.device_key === selectedDevice.key; }) || ({})
    readonly property var selectedSink: selectedAudio.sink || ({})
    readonly property var selectedSource: selectedAudio.source || ({})
    readonly property var selectedAudioProfiles: selectedAudio.profiles || []
    readonly property var activeAudioProfile: selectedAudioProfiles.find(function (profile) { return profile.key === selectedAudio.active_profile_key; }) || ({})
    hasSelection: filteredResults.length > 0
    selectionModel: results
    detailActions: providers.actionsFor(selectedResult)

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
    signal incomingTransferRequested
    signal screenshotRequested

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
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
        deactivateUiState();
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
    function captureScreenshot(x, y, width, height) {
        if (actionInFlight || modalPromptOpen || screenshotInFlight)
            return false;
        status = "Capturing Bluetooth window…";
        return screenshotCapture.captureRegion(x, y, width, height);
    }
    function applyObexSnapshot(capabilities) {
        obexCapabilities = capabilities || ({});
    }
    function applyAudioSnapshot(devices) {
        audioDevices = devices || [];
        audioStatus = "";
    }
    function applySnapshot(snapshot) {
        adapters = snapshot.adapters || [];
        preferredAdapterKey = BluetoothFlow.retainedAdapterKey(adapters, preferredAdapterKey);
        const enrichment = BluetoothBattery.enrichDevices(snapshot.devices, lastKnownBatteryByDevice);
        lastKnownBatteryByDevice = enrichment.cache;
        results.replaceProviderResults(provider.providerId, provider.resultsForDevices(enrichment.devices), false);
        if (BluetoothFlow.shouldStartScan(uiActive, powered, scanning, scanRequested)) {
            scanRequested = true;
            backend.setScanning(true, selectedAdapter.key);
        }
        status = BluetoothFlow.snapshotStatus(powered, scanning, filteredResults.length);
    }
    function statusForCompletedCall(id) {
        return BluetoothFlow.completedCallStatus(id, powered, status);
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
        status = BluetoothFlow.scanCompletionStatus(scan, filteredResults.length, status);
    }
    function sendFile(path) {
        if (!hasSelection || !path || actionInFlight || !obexCapabilities.outgoing_object_push)
            return false;
        status = "Starting file transfer to " + selectedDevice.name + "…";
        return backend.sendFile(selectedDevice.key, path);
    }
    function handleObexTransfer(transfer) {
        const transition = BluetoothFlow.transferTransition(activeTransfer, incomingTransferPrompt, transfer);
        if (!transition)
            return;
        activeTransfer = transition.activeTransfer;
        incomingTransferPrompt = transition.prompt;
        status = transition.status;
        if (transition.authorizationRequested)
            incomingTransferRequested();
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
    function handleOperationEvent(operation) {
        const deviceName = BluetoothFlow.operationDeviceName(filteredResults, (operation || ({})).device_key);
        const transition = BluetoothFlow.operationTransition(activeOperation, pairingPrompt, operation,
            deviceName, uiActive, powered, scanning);
        if (!transition)
            return;
        if (!transition.active && operation.snapshot)
            applySnapshot(operation.snapshot);
        activeOperation = transition.activeOperation;
        status = transition.status;
        if (transition.clearPairing) {
            pairingPrompt = null;
            pairingInput = "";
        }
        if (transition.rescan) {
            scanRequested = true;
            backend.setScanning(true, operation.adapter_key || selectedDevice.adapter_key || selectedAdapter.key);
        }
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
    function cycleDetailsTab() {
        if (!detailsOpen || !hasSelection)
            return false;
        const tabs = ["device", "audio", "adapter"];
        const currentIndex = Math.max(0, tabs.indexOf(detailsTab));
        detailsTab = tabs[(currentIndex + 1) % tabs.length];
        return true;
    }
    function primarySelected() { return hasSelection && providers.execute(selectedResult, "", { workspaceId: currentWorkspaceId }); }
    function triggerDetailAction(id) {
        if (!hasSelection)
            return false;
        const action = detailActions.find(function (candidate) { return candidate.id === id; }) || null;
        if (!action || action.visible === false || action.enabled === false)
            return false;
        if (action.confirmation && action.confirmation.required) {
            pendingConfirmationAction = action;
            return true;
        }
        return providers.execute(selectedResult, id, { workspaceId: currentWorkspaceId });
    }
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
        const request = BluetoothFlow.deviceActionRequest(actionId, device, trustAfterPair);
        if (!request)
            return false;
        if (request.status)
            status = request.status;
        return backend.deviceOperation(request.operation, device, request.values);
    }
    function setNoiseControl(mode) {
        if (!hasSelection || actionInFlight)
            return false;
        const request = BluetoothFlow.noiseControlRequest(selectedDevice, mode);
        if (!request.supported) {
            console.warn("shelllist bluetooth noise control rejected device_key=" + (selectedDevice.key || "")
                + " mode=" + mode + " reason=unsupported");
            return false;
        }
        if (request.unchanged)
            return true;
        status = request.status;
        return backend.deviceOperation("set-noise-control", selectedDevice, { mode: mode });
    }

    onModalPromptOpenChanged: if (!modalPromptOpen) Qt.callLater(focusSearchRequested)
    onSelectedResultChanged: pendingConfirmationAction = null

    Core.ProviderRegistry {
        id: providers
        BluetoothProvider { id: provider; controller: bluetoothController }
    }
    Core.ResultStore { id: results; registry: providers }
    Io.ClipboardScreenshotCapture {
        id: screenshotCapture
        active: bluetoothController.uiActive
        onCompleted: function (message) { bluetoothController.status = message; }
        onFailed: function (message) { bluetoothController.status = message; }
    }
    BluetoothBackend { id: backend; controller: bluetoothController }
}
