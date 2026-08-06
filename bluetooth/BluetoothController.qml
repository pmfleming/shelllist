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
    property string viewMode: "managed"
    property var pendingConfirmationAction
    property bool scanRequested: false
    property var radio: ({ available: false, operational: false, powered: false, adapter_count: 0,
        rfkill_present: false, soft_blocked: false, hard_blocked: false })
    property var management: ({ launch_state: "remember", reconnect_on_resume: true,
        trust_after_pair: true, preferred_adapter_key: "", show_blocked_devices: false,
        show_recent_devices: false })
    property var adapters: []
    property var allDevices: []
    property var audioDevices: []
    property var lastKnownBatteryByDevice: ({})
    property string audioStatus: ""
    property var obexCapabilities: ({})
    property var pairingPrompt: null
    property var incomingTransferPrompt: null
    property var activeOperations: ({})
    property var operationErrors: ({})
    property var activeTransfer: null
    property var activeScan: null
    property bool trustAfterPair: true
    property string preferredAdapterKey: ""
    property string pairingInput: ""
    property string status: "Loading Bluetooth devices…"
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
    readonly property var filteredResults: results.visibleResults
    readonly property var filteredResultsModel: results.visibleModel
    readonly property var selectedResult: results.selected()
    readonly property var selectedDevice: selectedResult ? selectedResult.payload : ({})
    navigationBlocked: modalPromptOpen
    readonly property var selectedAdapter: adapters.find(function (adapter) { return adapter.key === preferredAdapterKey; })
        || adapters.find(function (adapter) { return adapter.key === selectedDevice.adapter_key; })
        || adapters[0] || ({})
    readonly property var selectedAudio: audioDevices.find(function (audio) { return audio.device_key === selectedDevice.key; }) || ({})
    readonly property var selectedSink: selectedAudio.sink || ({})
    readonly property var selectedSource: selectedAudio.source || ({})
    readonly property var selectedAudioProfiles: selectedAudio.profiles || []
    readonly property var activeAudioProfile: selectedAudioProfiles.find(function (profile) { return profile.key === selectedAudio.active_profile_key; }) || ({})
    readonly property var selectedOperation: operationForDevice(selectedDevice.key)
    readonly property var selectedOperationError: operationErrorForDevice(selectedDevice.key)
    readonly property bool selectedDeviceBusy: !!selectedOperation
    readonly property bool globalRequestInFlight: backend.requestRunning
    readonly property bool actionInFlight: globalRequestInFlight || selectedDeviceBusy || canCancelTransfer || screenshotInFlight
    readonly property bool anyActionInFlight: backend.running || screenshotInFlight
    hasSelection: filteredResults.length > 0
    selectionModel: results
    detailActions: providers.actionsFor(selectedResult)

    readonly property bool pairingPromptOpen: !!pairingPrompt
    readonly property bool incomingTransferPromptOpen: !!incomingTransferPrompt
    readonly property bool confirmationOpen: !!pendingConfirmationAction
    readonly property bool modalPromptOpen: pairingPromptOpen || incomingTransferPromptOpen || confirmationOpen
    readonly property bool canCancelTransfer: !!activeTransfer && !["complete", "cancelled", "error"].includes(activeTransfer.status)
    readonly property bool canCancelOperation: !!selectedOperation && ["queued", "running"].includes(selectedOperation.state)
    readonly property bool powered: !!radio.operational
    readonly property bool scanning: !!activeScan
    readonly property bool discoveryMode: viewMode === "discovery"
    readonly property bool refreshInFlight: scanning || backend.isPending("snapshot") || backend.isPending("scan-start")
    signal incomingTransferRequested
    signal pairingInteractionRequested
    signal screenshotRequested

    function copyWith(values, key, value) {
        const result = Object.assign({}, values || ({}));
        result[key] = value;
        return result;
    }
    function copyWithout(values, key) {
        const result = Object.assign({}, values || ({}));
        delete result[key];
        return result;
    }
    function operationForDevice(deviceKey) {
        if (!deviceKey)
            return null;
        const requestIds = Object.keys(activeOperations || ({}));
        for (let index = 0; index < requestIds.length; index++) {
            const operation = activeOperations[requestIds[index]];
            if (operation.device_key === deviceKey)
                return operation;
        }
        return null;
    }
    function operationErrorForDevice(deviceKey) { return deviceKey ? (operationErrors[deviceKey] || null) : null; }
    function deviceBusy(deviceKey) { return !!operationForDevice(deviceKey); }
    function deviceDisplayName(device) {
        const base = device.name || device.remote_name || "Bluetooth device";
        const duplicate = allDevices.some(function (candidate) {
            return candidate.key !== device.key && (candidate.name || candidate.remote_name) === base;
        });
        if (!duplicate)
            return base;
        const adapter = adapters.find(function (candidate) { return candidate.key === device.adapter_key; }) || ({});
        return base + " · " + (adapter.alias || adapter.name || "adapter");
    }
    function devicesForView() {
        return BluetoothFlow.devicesForView(allDevices, viewMode, management);
    }
    function rebuildResults(resetSelection) {
        results.replaceProviderResults(provider.providerId, provider.resultsForDevices(devicesForView()), !!resetSelection);
    }
    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        scanRequested = false;
        refresh();
        backend.refreshObex();
    }
    function deactivateUi() {
        pendingConfirmationAction = null;
        scanRequested = false;
        if (activeScan)
            backend.setScanning(false, activeScan.adapter_key);
        activeScan = null;
        deactivateUiState();
    }
    function handleTransportFailure(message) {
        scanRequested = false;
        activeOperations = ({});
        activeTransfer = null;
        activeScan = null;
        status = message;
    }
    function refresh() {
        status = scanning ? "Scanning for Bluetooth devices…" : "Refreshing Bluetooth devices…";
        backend.refresh();
    }
    function refreshList() {
        if (discoveryMode)
            toggleScan();
        else
            refresh();
    }
    function openAdapterSettings() {
        detailsTab = "adapter";
        detailsOpen = true;
    }
    function setViewMode(mode) {
        if (!["managed", "discovery"].includes(mode) || viewMode === mode)
            return;
        if (scanning)
            backend.setScanning(false, activeScan.adapter_key);
        activeScan = null;
        scanRequested = false;
        viewMode = mode;
        detailsOpen = false;
        rebuildResults(true);
        if (discoveryMode && powered) {
            scanRequested = true;
            backend.setScanning(true, selectedAdapter.key);
        }
        status = statusForSnapshot();
    }
    function captureScreenshot(x, y, width, height) {
        if (anyActionInFlight || modalPromptOpen || screenshotInFlight)
            return false;
        status = "Capturing Bluetooth window…";
        return screenshotCapture.captureRegion(x, y, width, height);
    }
    function applyObexSnapshot(capabilities) { obexCapabilities = capabilities || ({}); }
    function applyAudioSnapshot(devices) { audioDevices = devices || []; audioStatus = ""; }
    function applySnapshot(snapshot) {
        radio = snapshot.radio || ({ available: (snapshot.adapters || []).length > 0,
            operational: (snapshot.adapters || []).some(function (adapter) { return adapter.powered; }),
            powered: (snapshot.adapters || []).some(function (adapter) { return adapter.powered; }),
            adapter_count: (snapshot.adapters || []).length, rfkill_present: false,
            soft_blocked: false, hard_blocked: false });
        adapters = snapshot.adapters || [];
        management = snapshot.management || management;
        trustAfterPair = management.trust_after_pair !== false;
        const policyAdapter = management.preferred_adapter_key || preferredAdapterKey;
        preferredAdapterKey = BluetoothFlow.retainedAdapterKey(adapters, policyAdapter);
        const enrichment = BluetoothBattery.enrichDevices(snapshot.devices, lastKnownBatteryByDevice);
        lastKnownBatteryByDevice = enrichment.cache;
        allDevices = enrichment.devices;
        rebuildResults(false);
        if (BluetoothFlow.shouldStartScan(uiActive && discoveryMode, powered, scanning, scanRequested)) {
            scanRequested = true;
            backend.setScanning(true, selectedAdapter.key);
        }
        status = statusForSnapshot();
    }
    function statusForSnapshot() {
        return BluetoothFlow.radioStatus(radio, discoveryMode, scanning, filteredResults.length);
    }
    function statusForCompletedCall(id) {
        return BluetoothFlow.completedCallStatus(id, powered, status);
    }
    function setPower() {
        if (radio.hard_blocked) {
            status = "Use the hardware radio switch to enable Bluetooth";
            return false;
        }
        status = powered ? "Turning Bluetooth off…" : "Turning Bluetooth on…";
        scanRequested = false;
        return backend.setPowered(!powered, null);
    }
    function setAdapterPower(adapter, value) {
        if (!adapter || !adapter.key || backend.requestRunning)
            return false;
        status = (value ? "Turning on " : "Turning off ") + (adapter.alias || adapter.name || "Bluetooth adapter") + "…";
        return backend.setPowered(!!value, adapter.key);
    }
    function toggleScan() {
        if (!discoveryMode) {
            refresh();
            return;
        }
        status = scanning ? "Stopping Bluetooth scan…" : "Scanning for Bluetooth devices…";
        scanRequested = true;
        backend.setScanning(!scanning, selectedAdapter.key);
    }
    function handleScanEvent(scan) {
        if (!scan || !scan.request_id)
            return;
        if (scan.state === "running") {
            activeScan = scan;
            if (scan.snapshot) applySnapshot(scan.snapshot);
            status = "Scanning for Bluetooth devices…";
            return;
        }
        if (activeScan && activeScan.request_id === scan.request_id) activeScan = null;
        if (scan.snapshot) applySnapshot(scan.snapshot);
        status = BluetoothFlow.scanCompletionStatus(scan, filteredResults.length, status);
    }
    function updateManagement(values) {
        if (backend.requestRunning)
            return false;
        status = "Saving Bluetooth management settings…";
        return backend.updateManagement(values);
    }
    function setPreferredAdapter(key) {
        if (!key || key === preferredAdapterKey)
            return;
        preferredAdapterKey = key;
        updateManagement({ preferred_adapter_key: key });
    }
    function setTrustAfterPair(value) {
        trustAfterPair = !!value;
        updateManagement({ trust_after_pair: trustAfterPair });
    }
    function sendFile(path) {
        if (!hasSelection || !path || actionInFlight || !obexCapabilities.outgoing_object_push)
            return false;
        status = "Starting file transfer to " + selectedDevice.name + "…";
        return backend.sendFile(selectedDevice.key, path);
    }
    function handleObexTransfer(transfer) {
        const transition = BluetoothFlow.transferTransition(activeTransfer, incomingTransferPrompt, transfer);
        if (!transition) return;
        activeTransfer = transition.activeTransfer;
        incomingTransferPrompt = transition.prompt;
        status = transition.status;
        if (transition.authorizationRequested) incomingTransferRequested();
    }
    function respondIncomingTransfer(accept) {
        if (!incomingTransferPromptOpen) return false;
        const requestId = incomingTransferPrompt.request_id;
        incomingTransferPrompt = null;
        status = accept ? "Accepting incoming file…" : "Rejecting incoming file…";
        return backend.respondObex(requestId, accept);
    }
    function cancelActiveTransfer() {
        if (!canCancelTransfer) return false;
        status = "Cancelling file transfer…";
        return backend.cancelTransfer(activeTransfer.request_id);
    }
    function handleOperationAccepted(operation) {
        if (!operation || !operation.request_id) return;
        if (!activeOperations[operation.request_id])
            activeOperations = copyWith(activeOperations, operation.request_id, operation);
        operationErrors = copyWithout(operationErrors, operation.device_key);
        rebuildResults(false);
    }
    function handleOperationEvent(operation) {
        if (!operation || !operation.request_id) return;
        const device = allDevices.find(function (candidate) { return candidate.key === operation.device_key; }) || ({});
        const deviceName = device.name || "Bluetooth device";
        if (BluetoothFlow.isActiveOperation(operation)) {
            activeOperations = copyWith(activeOperations, operation.request_id, operation);
            operationErrors = copyWithout(operationErrors, operation.device_key);
            status = BluetoothFlow.activeOperationStatus(operation, deviceName);
            rebuildResults(false);
            return;
        }
        activeOperations = copyWithout(activeOperations, operation.request_id);
        if (operation.operation === "pair" && operation.state === "completed" && discoveryMode)
            setViewMode("managed");
        if (operation.state === "failed")
            operationErrors = copyWith(operationErrors, operation.device_key, operation.error || ({ message: "Bluetooth operation failed" }));
        else
            operationErrors = copyWithout(operationErrors, operation.device_key);
        if (operation.snapshot) applySnapshot(operation.snapshot); else rebuildResults(false);
        status = BluetoothFlow.operationCompletionStatus(operation, deviceName);
        if (pairingPrompt && pairingPrompt.device_key === operation.device_key) {
            pairingPrompt = null;
            pairingInput = "";
        }
        if (BluetoothFlow.shouldRescanAfterOperation(operation, uiActive && discoveryMode, powered, scanning)) {
            scanRequested = true;
            backend.setScanning(true, operation.adapter_key || device.adapter_key || selectedAdapter.key);
        }
    }
    function cancelActiveOperation() {
        if (!canCancelOperation) return false;
        status = "Cancelling Bluetooth operation…";
        return backend.cancelOperation(selectedOperation.request_id);
    }
    function handlePairingEvent(event) {
        const transition = BluetoothFlow.pairingTransition(pairingPrompt, event);
        if (!transition.changed) return;
        pairingPrompt = transition.prompt;
        pairingInput = "";
        if (pairingPrompt) {
            status = pairingPrompt.response_required ? "Pairing confirmation required" : "Complete pairing on the Bluetooth device";
            pairingInteractionRequested();
        } else if (event.data && event.data.reason === "timeout") {
            status = "Bluetooth pairing request timed out";
        }
    }
    function respondPairing(accept) {
        if (!pairingPromptOpen || !pairingPrompt.response_required) return false;
        const requestId = pairingPrompt.request_id;
        const value = pairingInput;
        pairingPrompt = null;
        pairingInput = "";
        return backend.respondPairing(requestId, accept, value);
    }
    function adapterOperation(operation, values) {
        if (!selectedAdapter.key || backend.requestRunning) {
            status = backend.requestRunning ? "Wait for the current Bluetooth setting to finish…" : "No Bluetooth adapter is selected.";
            return false;
        }
        status = "Updating Bluetooth adapter…";
        return backend.adapterOperation(operation, selectedAdapter, values || ({}));
    }
    function setAudioProfile(profile) {
        if (!hasSelection || !profile || !profile.key || !profile.available || actionInFlight) return false;
        status = "Switching Bluetooth audio to " + profile.label + "…";
        return backend.setAudioProfile(selectedDevice.key, profile.key);
    }
    function renameSelected(alias) {
        const value = (alias || "").trim();
        if (!hasSelection || value.length === 0 || value === selectedDevice.name || selectedDeviceBusy) return false;
        status = "Renaming " + selectedDevice.name + "…";
        return backend.deviceOperation("set-alias", selectedDevice, { alias: value });
    }
    function resetSelectedName() {
        if (!hasSelection || selectedDeviceBusy) return false;
        status = "Resetting Bluetooth device name…";
        return backend.deviceOperation("reset-alias", selectedDevice, {});
    }
    function cycleDetailsTab() {
        if (!detailsOpen || !hasSelection) return false;
        const tabs = ["device", "audio", "adapter"];
        const currentIndex = Math.max(0, tabs.indexOf(detailsTab));
        detailsTab = tabs[(currentIndex + 1) % tabs.length];
        return true;
    }
    function primarySelected() { return hasSelection && providers.execute(selectedResult, "", { workspaceId: currentWorkspaceId }); }
    function triggerDetailAction(id) {
        if (!hasSelection) return false;
        const action = detailActions.find(function (candidate) { return candidate.id === id; }) || null;
        if (!action || action.visible === false || action.enabled === false) return false;
        if (action.confirmation && action.confirmation.required) {
            pendingConfirmationAction = action;
            return true;
        }
        return providers.execute(selectedResult, id, { workspaceId: currentWorkspaceId });
    }
    function cancelPendingConfirmation() { pendingConfirmationAction = null; }
    function confirmPendingAction() {
        if (!pendingConfirmationAction) return false;
        const actionId = pendingConfirmationAction.id;
        pendingConfirmationAction = null;
        return hasSelection && providers.execute(selectedResult, actionId, { workspaceId: currentWorkspaceId });
    }
    function executeDeviceAction(actionId, device) {
        if (deviceBusy(device.key) || backend.requestRunning) return false;
        const request = BluetoothFlow.deviceActionRequest(actionId, device, trustAfterPair);
        if (!request) return false;
        if (request.status) status = request.status;
        return backend.deviceOperation(request.operation, device, request.values);
    }
    function setNoiseControl(mode) {
        if (!hasSelection || selectedDeviceBusy || backend.requestRunning) return false;
        const request = BluetoothFlow.noiseControlRequest(selectedDevice, mode);
        if (!request.supported) return false;
        if (request.unchanged) return true;
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
