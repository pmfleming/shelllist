import QtQuick
import Qt.labs.settings
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "BluetoothBattery.js" as BluetoothBattery
import "BluetoothFlow.js" as BluetoothFlow

Ui.ProviderChooserController {
    id: bluetoothController

    provider: BluetoothProvider { id: bluetoothProvider; controller: bluetoothController }
    property string detailsTab: "device"
    property alias searchScope: scopeSettings.searchScope
    property var pendingConfirmationAction
    property bool scanRequested: false
    property var radio: BluetoothFlow.emptyRadio()
    property var management: ({ launch_state: "remember", reconnect_on_resume: true,
        trust_after_pair: true, preferred_adapter_key: "", show_blocked_devices: false,
        show_recent_devices: false })
    property var adapters: []
    property var allDevices: []
    property var audioDevices: []
    property var lastKnownBatteryByDevice: ({})
    property string audioStatus: ""
    property var pairingPrompt: null
    readonly property alias activeOperations: operationState.activeOperations
    readonly property alias operationErrors: operationState.errorsByDevice
    property var activeScan: null
    property bool trustAfterPair: true
    property string preferredAdapterKey: ""
    property string pairingInput: ""
    property string status: "Loading Bluetooth devices…"
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
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
    actionInFlight: globalRequestInFlight || selectedDeviceBusy || screenshotInFlight
    readonly property bool anyActionInFlight: backend.running || screenshotInFlight

    readonly property bool pairingPromptOpen: !!pairingPrompt
    readonly property bool confirmationOpen: !!pendingConfirmationAction
    readonly property bool modalPromptOpen: pairingPromptOpen || confirmationOpen
    readonly property bool canCancelOperation: !!selectedOperation && ["queued", "running"].includes(selectedOperation.state)
    readonly property bool powered: !!radio.operational
    readonly property bool scanning: !!activeScan
    readonly property bool searchAllDevices: searchScope === "all"
    readonly property bool refreshInFlight: scanning || backend.isPending("snapshot") || backend.isPending("scan-start")
    signal pairingInteractionRequested

    Settings {
        id: scopeSettings
        category: "ShelllistBluetooth"
        property string searchScope: "mine"
    }

    function operationForDevice(deviceKey) { return operationState.forDevice(deviceKey); }
    function operationErrorForDevice(deviceKey) { return operationState.errorForDevice(deviceKey); }
    function deviceBusy(deviceKey) { return !!operationState.forDevice(deviceKey); }
    function devicesForView() {
        return BluetoothFlow.devicesForView(allDevices, searchScope, management);
    }
    function rebuildResults(resetSelection) {
        replaceProviderResults(bluetoothProvider.resultsForDevices(devicesForView()), !!resetSelection);
    }
    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        scanRequested = false;
        refresh();
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
        operationState.reset();
        activeScan = null;
        status = message;
    }
    function refresh() {
        status = scanning ? "Scanning for Bluetooth devices…" : "Refreshing Bluetooth devices…";
        backend.refresh();
    }
    function refreshList() {
        if (searchAllDevices)
            toggleScan();
        else
            refresh();
    }
    function openAdapterSettings() {
        detailsTab = "adapter";
        detailsOpen = true;
    }
    function setSearchScope(scope) {
        if (!["mine", "all"].includes(scope) || searchScope === scope)
            return;
        if (scanning)
            backend.setScanning(false, activeScan.adapter_key);
        activeScan = null;
        scanRequested = false;
        searchScope = scope;
        detailsOpen = false;
        rebuildResults(true);
        if (searchAllDevices && powered) {
            scanRequested = true;
            backend.setScanning(true, selectedAdapter.key);
        }
        status = statusForSnapshot();
    }
    function toggleSearchScope() {
        setSearchScope(searchAllDevices ? "mine" : "all");
    }
    function captureScreenshot(x, y, width, height) {
        return screenshotCapture.captureRegion(x, y, width, height);
    }
    function applyAudioSnapshot(devices) { audioDevices = devices || []; audioStatus = ""; }
    function applyRequestSnapshot(requests) {
        const values = requests || ({});
        const operationRequests = values.operations || ({});
        operationState.restore(operationRequests.active || []);
        const scanRequests = (values.scans || {}).active || [];
        activeScan = scanRequests.length > 0 ? scanRequests[0] : null;
        scanRequested = !!activeScan;
        const pairingRequests = (values.pairing || {}).active || [];
        pairingPrompt = pairingRequests.length > 0
            ? pairingRequests[pairingRequests.length - 1] : null;
        pairingInput = "";
        if (pairingPrompt) {
            status = pairingPrompt.response_required
                ? "Recovered Bluetooth pairing confirmation"
                : "Recovered active Bluetooth pairing";
            pairingInteractionRequested();
        } else if (Object.keys(operationState.activeOperations).length > 0) {
            status = "Recovered active Bluetooth operation";
        }
    }
    function applySnapshot(snapshot) {
        radio = BluetoothFlow.radioForSnapshot(snapshot);
        adapters = snapshot.adapters || [];
        management = snapshot.management || management;
        trustAfterPair = management.trust_after_pair !== false;
        const policyAdapter = management.preferred_adapter_key || preferredAdapterKey;
        preferredAdapterKey = BluetoothFlow.retainedAdapterKey(adapters, policyAdapter);
        const enrichment = BluetoothBattery.enrichDevices(snapshot.devices, lastKnownBatteryByDevice);
        lastKnownBatteryByDevice = enrichment.cache;
        allDevices = enrichment.devices;
        rebuildResults(false);
        if (BluetoothFlow.shouldStartScan(uiActive && searchAllDevices, powered, scanning, scanRequested)) {
            scanRequested = true;
            backend.setScanning(true, selectedAdapter.key);
        }
        status = statusForSnapshot();
    }
    function statusForSnapshot() {
        return BluetoothFlow.radioStatus(radio, searchAllDevices, scanning, filteredResults.length);
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
        if (!searchAllDevices) {
            refresh();
            return;
        }
        status = scanning ? "Stopping Bluetooth scan…" : "Scanning for Bluetooth devices…";
        scanRequested = true;
        backend.setScanning(!scanning, selectedAdapter.key);
    }
    function handleScanEvent(scan) {
        const transition = BluetoothFlow.scanTransition(
            activeScan, scan, filteredResults.length, status);
        if (!transition)
            return;
        activeScan = transition.activeScan;
        if (transition.snapshot)
            applySnapshot(transition.snapshot);
        status = transition.status;
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
    function handleOperationAccepted(operation) { operationState.accept(operation); }
    function handleOperationEvent(operation) { operationState.handle(operation); }
    function dismissNavigation() {
        if (navigationHelpOpen) {
            closeNavigationHelp();
            return true;
        }
        if (modalPromptOpen)
            return false;
        if (canCancelOperation)
            return cancelActiveOperation();
        if (detailsOpen) {
            closeDetails();
            return true;
        }
        closeWindowRequested();
        return true;
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
        if (!hasSelection || !profile || !profile.key || profile.available === false || actionInFlight) return false;
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
        const tabs = ["device", "information", "adapter"];
        const currentIndex = Math.max(0, tabs.indexOf(detailsTab));
        detailsTab = tabs[(currentIndex + 1) % tabs.length];
        return true;
    }
    function primarySelected() { return hasSelection && executeSelected(""); }
    function triggerDetailAction(id) {
        if (!hasSelection) return false;
        const action = detailActions.find(function (candidate) { return candidate.id === id; }) || null;
        if (!action || action.visible === false || action.enabled === false) return false;
        if (action.confirmation && action.confirmation.required) {
            pendingConfirmationAction = action;
            return true;
        }
        return executeSelected(id);
    }
    function cancelPendingConfirmation() { pendingConfirmationAction = null; }
    function confirmPendingAction() {
        if (!pendingConfirmationAction) return false;
        const actionId = pendingConfirmationAction.id;
        pendingConfirmationAction = null;
        return hasSelection && executeSelected(actionId);
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

    Io.ClipboardScreenshotCapture {
        id: screenshotCapture
        active: bluetoothController.uiActive
        blocked: bluetoothController.anyActionInFlight || bluetoothController.modalPromptOpen
        startMessage: "Capturing Bluetooth window…"
        onStatusChanged: function (message) { bluetoothController.status = message; }
    }
    BluetoothBackend { id: backend; controller: bluetoothController }
    BluetoothOperationController {
        id: operationState
        controller: bluetoothController
        backend: backend
    }
}
