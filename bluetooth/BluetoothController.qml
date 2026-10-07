import Quickshell
import QtCore
import QtQuick
import Shelllist.Ui as Ui
import "BluetoothFlow.js" as BluetoothFlow

Ui.ProviderChooserController {
    id: bluetoothController

    provider: BluetoothProvider {
        id: bluetoothProvider
        controller: bluetoothController
    }
    sharedScreenshotEnabled: true
    sharedScreenshotBlocked: anyActionInFlight || modalPromptOpen
    sharedScreenshotStartMessage: "Capturing Bluetooth window…"
    onSharedScreenshotStatusChanged: function (message) {
        status = message;
    }

    readonly property alias nameEdits: nameEditState
    readonly property alias adapterEdits: adapterEditState
    property string detailsTab: "device"
    viewMemory: detailsTab === "adapter" ? adapterMemory : deviceMemory
    readonly property Ui.ChooserMemory adapterMemory: Ui.ChooserMemory {
        controller: bluetoothController
        enabled: bluetoothController.detailsTab === "adapter"
        key: "bluetooth-settings::" + (bluetoothController.selectedAdapter.key || "global")
        tab: bluetoothController.adapterSettingsTab
        tabs: ["general", "pairing"]
        onRestoreRequested: function (open, tab) {
            // Selecting a radio is explicit settings navigation, not a request
            // to close the inspector. Only its presentation tab/scroll changes.
            bluetoothController.adapterSettingsTab = tab;
        }
    }
    readonly property Ui.ChooserMemory deviceMemory: Ui.ChooserMemory {
        controller: bluetoothController
        enabled: bluetoothController.detailsTab !== "adapter"
        key: bluetoothController.selectedResult ? bluetoothController.selectedResult.key : ""
        tab: bluetoothController.detailsTab
        tabs: ["device", "settings", "information"]
        onRestoreRequested: function (open, tab) {
            bluetoothController.detailsTab = tab;
            bluetoothController.detailsOpen = open;
        }
        onKeyChanged: if (key && !enabled && !bluetoothController.detailsOpen)
            bluetoothController.detailsTab = "device"
    }
    property string adapterSettingsTab: "general"
    property alias searchScope: scopeSettings.searchScope
    property var pendingConfirmationAction
    property bool scanRequested: false
    property var radio: BluetoothFlow.emptyRadio()
    property var management: ({
            launch_state: "remember",
            reconnect_on_resume: true,
            trust_after_pair: true,
            preferred_adapter_key: "",
            show_blocked_devices: false,
            show_recent_devices: false
        })
    property bool backendAvailable: false
    property string listError: ""
    property bool backendLoading: false
    property var adapters: []
    property var allDevices: []
    property var audioDevices: []
    // Presentation only: never reuse cached endpoints for audio operations.
    property var audioPresentationByDevice: ({})
    property string audioStatus: ""
    property var pairingPrompts: []
    property var pairingInputs: ({})
    // Closed sensitive prompts must not be restored by a late event/snapshot.
    property var dismissedPairingIds: ({})
    readonly property var pairingPrompt: pairingPrompts.length > 0 ? pairingPrompts[0] : null
    property string respondingPairingId: ""
    readonly property bool pairingResponsePending: backend.isPending("pairing-response") || (!!pairingPrompt && respondingPairingId === pairingPrompt.request_id)
    readonly property alias activeOperations: operationState.activeOperations
    property var activeScan: null
    property bool trustAfterPair: true
    property string preferredAdapterKey: ""
    property string pairingInput: ""
    property string status: "Loading Bluetooth devices…"
    readonly property bool screenshotInFlight: sharedScreenshotInFlight
    readonly property var selectedDevice: selectedResult ? selectedResult.payload : ({})
    navigationBlocked: modalPromptOpen
    readonly property var selectedAdapter: adapters.find(function (adapter) {
        return adapter.key === preferredAdapterKey;
    }) || adapters.find(function (adapter) {
        return adapter.key === selectedDevice.adapter_key;
    }) || adapters[0] || ({})
    readonly property var selectedAudio: audioDevices.find(function (audio) {
        return audio.device_key === selectedDevice.key;
    }) || ({})
    readonly property var selectedAudioPresentation: audioPresentationByDevice[selectedDevice.key] || ({})
    readonly property var selectedSink: selectedAudio.sink || ({})
    readonly property var selectedSource: selectedAudio.source || ({})
    readonly property var selectedAudioProfiles: selectedAudio.profiles || []
    readonly property var selectedOperation: operationForDevice(selectedDevice.key)
    readonly property var selectedOperationError: operationErrorForDevice(selectedDevice.key)
    readonly property bool selectedDeviceBusy: !!selectedOperation
    readonly property bool globalRequestInFlight: !backendAvailable || backend.requestRunning
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
        location: "file://" + (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/shelllist.ini"
        category: "Bluetooth"
        property string searchScope: "mine"
    }

    function operationForDevice(deviceKey) {
        return operationState.forDevice(deviceKey);
    }
    function operationErrorForDevice(deviceKey) {
        return operationState.errorForDevice(deviceKey);
    }
    function deviceBusy(deviceKey) {
        return !!operationState.forDevice(deviceKey);
    }
    function devicesForView() {
        return BluetoothFlow.devicesForView(allDevices, searchScope, management);
    }
    function rebuildResults(resetSelection) {
        replaceProviderResults(bluetoothProvider.resultsFor(devicesForView()), !!resetSelection);
    }
    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        scanRequested = false;
        refresh();
    }
    function deactivateUi() {
        prepareUiDeactivation();
        cancelSensitivePrompts();
        pendingConfirmationAction = null;
        scanRequested = false;
        if (activeScan)
            backend.setScanning(false, activeScan.adapter_key);
        activeScan = null;
        deactivateUiState();
    }
    function invalidateBluetooth(message) {
        listError = message;
        backendLoading = false;
        backendAvailable = false;
        radio = BluetoothFlow.emptyRadio();
        adapters = [];
        allDevices = [];
        invalidateAudio(message);
        replacePairingPrompts([]);
        respondingPairingId = "";
        activeScan = null;
        scanRequested = false;
        operationState.reset();
        rebuildResults(false);
        status = message;
    }
    function invalidateAudio(message) {
        audioDevices = [];
        audioStatus = message;
    }
    function handleTransportFailure(message) {
        nameEditState.transportFailed(message);
        adapterEditState.transportFailed(message);
        invalidateBluetooth(message);
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
    function setSearchScope(scope) {
        if (!["mine", "all"].includes(scope) || searchScope === scope)
            return;
        if (scanning)
            backend.setScanning(false, activeScan.adapter_key);
        activeScan = null;
        scanRequested = false;
        searchScope = scope;
        rebuildResults(true);
        if (searchAllDevices && powered) {
            scanRequested = true;
            backend.setScanning(true, selectedAdapter.key);
        }
        status = statusForSnapshot();
    }
    function applyAudioSnapshot(devices) {
        const presentation = Object.assign({}, audioPresentationByDevice);
        for (const audio of devices || []) {
            presentation[audio.device_key] = BluetoothFlow.audioPresentation(audio, presentation[audio.device_key]);
        }
        audioPresentationByDevice = presentation;
        audioDevices = devices || [];
        audioStatus = "";
    }
    function applyRequestSnapshot(requests: var): void {
        const state = BluetoothFlow.requestState(requests);
        operationState.restore(state.operations);
        activeScan = state.activeScan;
        scanRequested = !!activeScan;
        replacePairingPrompts(state.pairingPrompts || []);
        if (!backend.isPending("pairing-response"))
            respondingPairingId = "";
        if (pairingPrompt) {
            status = pairingPrompt.response_required ? "Recovered Bluetooth pairing confirmation" : "Recovered active Bluetooth pairing";
            pairingInteractionRequested();
        } else if (state.operations.length > 0) {
            status = "Recovered active Bluetooth operation";
        }
    }
    function applySnapshot(snapshot) {
        listError = "";
        backendLoading = false;
        const recovering = !backendAvailable;
        backendAvailable = true;
        if (recovering)
            Qt.callLater(function () {
                backend.recoverRequests();
                backend.refreshAudio();
            });
        radio = BluetoothFlow.radioForSnapshot(snapshot);
        adapters = snapshot.adapters || [];
        management = snapshot.management || management;
        trustAfterPair = management.trust_after_pair !== false;
        const policyAdapter = management.preferred_adapter_key || preferredAdapterKey;
        preferredAdapterKey = BluetoothFlow.retainedAdapterKey(adapters, policyAdapter);
        allDevices = snapshot.devices || [];
        const presentation = ({});
        for (const device of allDevices) {
            if (audioPresentationByDevice[device.key])
                presentation[device.key] = audioPresentationByDevice[device.key];
        }
        audioPresentationByDevice = presentation;
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
        status = (value ? "Turning on " : "Turning off ") + BluetoothFlow.adapterLabel(adapter) + "…";
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
        const transition = BluetoothFlow.scanTransition(activeScan, scan, filteredResults.length, status);
        if (!transition)
            return;
        activeScan = transition.activeScan;
        if (transition.snapshot)
            applySnapshot(transition.snapshot);
        if (scan.state === "failed" && !transition.activeScan)
            listError = transition.status;
        else if (scan.state === "running")
            listError = "";
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
        updateManagement({
            preferred_adapter_key: key
        });
    }
    function setTrustAfterPair(value) {
        trustAfterPair = !!value;
        updateManagement({
            trust_after_pair: trustAfterPair
        });
    }
    function handleOperationAccepted(operation) {
        operationState.accept(operation);
        nameEditState.observe(operation);
    }
    function handleOperationEvent(operation) {
        operationState.handle(operation);
        nameEditState.observe(operation);
    }
    function dismissNavigation(): bool {
        if (modalPromptOpen)
            return false;
        if (canCancelOperation)
            return cancelActiveOperation();
        return dismissDetailsOrWindow();
    }
    function cancelActiveOperation() {
        if (!canCancelOperation)
            return false;
        status = "Cancelling Bluetooth operation…";
        return backend.cancelOperation(selectedOperation.request_id);
    }
    function cancelSensitivePrompts(): void {
        const dismissed = Object.assign(Object.create(null), dismissedPairingIds);
        for (const prompt of pairingPrompts) {
            dismissed[prompt.request_id] = true;
            // A submitted response already owns its request; never replace its
            // identity or race it with a second contradictory response.
            if (prompt.response_required && prompt.request_id !== respondingPairingId)
                backend.cancelPairingPrompt(prompt.request_id);
        }
        dismissedPairingIds = dismissed;
        replacePairingPrompts([]);
    }
    function replacePairingPrompts(prompts) {
        prompts = prompts.filter(function (prompt) {
            return !Object.prototype.hasOwnProperty.call(dismissedPairingIds, prompt.request_id);
        });
        const inputs = Object.assign({}, pairingInputs);
        if (pairingPrompt)
            inputs[pairingPrompt.request_id] = pairingInput;
        const retained = ({});
        for (const prompt of prompts)
            retained[prompt.request_id] = inputs[prompt.request_id] || "";
        pairingInputs = retained;
        pairingPrompts = prompts;
        pairingInput = pairingPrompt ? retained[pairingPrompt.request_id] : "";
    }
    function handlePairingEvent(event) {
        const previousId = pairingPrompt ? pairingPrompt.request_id : "";
        replacePairingPrompts(BluetoothFlow.pairingQueue(pairingPrompts, event));
        const nextId = pairingPrompt ? pairingPrompt.request_id : "";
        status = BluetoothFlow.pairingStatus(pairingPrompt, event) || status;
        if (nextId && previousId !== nextId)
            pairingInteractionRequested();
    }
    function closePairingForDevice(deviceKey) {
        replacePairingPrompts(pairingPrompts.filter(function (prompt) {
            return prompt.device_key !== deviceKey;
        }));
    }
    function finishPairingResponse(success) {
        const requestId = respondingPairingId;
        respondingPairingId = "";
        if (success)
            handlePairingEvent({
                event: "answered",
                data: {
                    request_id: requestId
                }
            });
    }
    function respondPairing(accept) {
        if (!pairingPromptOpen || !pairingPrompt.response_required || pairingResponsePending)
            return false;
        const requestId = pairingPrompt.request_id;
        respondingPairingId = requestId;
        const sent = backend.respondPairing(requestId, accept, pairingInput);
        if (!sent)
            respondingPairingId = "";
        // Keep the prompt/input until the backend accepts the response, so a
        // validation or transport error does not strand the pending request.
        return sent;
    }
    function adapterOperation(operation, values) {
        if (!selectedAdapter.key || backend.requestRunning) {
            status = backend.requestRunning ? "Wait for the current Bluetooth setting to finish…" : "No Bluetooth adapter is selected.";
            return false;
        }
        status = "Updating Bluetooth adapter…";
        return backend.adapterOperation(operation, selectedAdapter, values || ({}));
    }
    function updateDevicePolicy(values) {
        if (!hasSelection || actionInFlight)
            return false;
        status = "Saving device policy…";
        return backend.updateDevicePolicy(selectedDevice.key, values);
    }
    function setAudioDefault(endpoint) {
        if (!hasSelection || !selectedDevice.connected || !selectedAudio.device_key || actionInFlight || !endpoint || !endpoint.key || !endpoint.ready)
            return false;
        status = "Updating default Bluetooth audio route…";
        return backend.setAudioDefault(selectedDevice.key, endpoint.key);
    }
    function setAudioProfile(profile) {
        if (!hasSelection || !selectedDevice.connected || !selectedAudio.device_key || !profile || !profile.key || profile.available === false || actionInFlight)
            return false;
        status = "Switching Bluetooth audio to " + profile.label + "…";
        return backend.setAudioProfile(selectedDevice.key, profile.key);
    }
    function renameSelected(alias) {
        if (!hasSelection || actionInFlight)
            return false;
        nameEditState.edit(selectedDevice.key, alias || "");
        return nameEditState.save(selectedDevice.key);
    }
    function resetSelectedName() {
        if (!hasSelection || selectedDeviceBusy)
            return false;
        status = "Resetting Bluetooth device name…";
        return backend.deviceOperation("reset-alias", selectedDevice, {});
    }
    function openBluetoothSettings() {
        viewMemory.synchronize();
        detailsTab = "adapter";
        viewMemory.synchronize();
        detailsOpen = true;
    }
    function toggleBluetoothSettings() {
        if (detailsOpen && detailsTab === "adapter")
            closeDetails();
        else
            openBluetoothSettings();
    }
    function openDetails() {
        if (!hasSelection)
            return;
        if (detailsTab === "adapter")
            detailsTab = "device";
        viewMemory.synchronize();
        detailsOpen = true;
    }
    function toggleDetails() {
        viewMemory.synchronize();
        if (detailsTab === "adapter")
            openDetails();
        else
            detailsOpen ? closeDetails() : openDetails();
    }
    function cycleDetailsTab(backwards: bool): bool {
        if (!detailsOpen)
            return false;
        if (detailsTab === "adapter") {
            adapterSettingsTab = adapterSettingsTab === "general" ? "pairing" : "general";
            return true;
        }
        if (!hasSelection)
            return false;
        const tabs = ["device", "settings", "information"];
        detailsTab = tabAfter(tabs, detailsTab, backwards);
        return true;
    }
    function primarySelected() {
        return hasSelection && executeSelected("");
    }
    function enabledDetailAction(id: string): var {
        const action = detailActions.find(function (candidate) {
            return candidate.id === id;
        });
        return action && action.visible !== false && action.enabled !== false ? action : null;
    }
    function triggerDetailAction(id) {
        if (!hasSelection)
            return false;
        const action = enabledDetailAction(id);
        if (!action)
            return false;
        if (!action.confirmation || !action.confirmation.required)
            return executeSelected(id);
        pendingConfirmationAction = action;
        return true;
    }
    function cancelPendingConfirmation() {
        pendingConfirmationAction = null;
    }
    function confirmPendingAction() {
        if (!pendingConfirmationAction)
            return false;
        const actionId = pendingConfirmationAction.id;
        pendingConfirmationAction = null;
        return hasSelection && executeSelected(actionId);
    }
    function executeDeviceAction(actionId, device) {
        if (deviceBusy(device.key) || backend.requestRunning)
            return false;
        if (actionId === "reset-policy") {
            status = "Saving device policy…";
            return backend.updateDevicePolicy(device.key, {
                reconnect_on_resume: null,
                trust_after_pair: null,
                power_on_connect: null,
                wait_for_services: null,
                fast_pair_controls_enabled: null,
                audio_route_on_connect: null,
                preferred_audio_profile_key: null
            });
        }
        const request = BluetoothFlow.deviceActionRequest(actionId, device, trustAfterPair);
        if (!request)
            return false;
        if (request.status)
            status = request.status;
        return backend.deviceOperation(request.operation, device, request.values);
    }
    // ModalFrame restores valid preceding focus. Never enqueue a search-focus
    // request here: it can outlive closure and overwrite the next invocation.
    onSelectedResultChanged: pendingConfirmationAction = null

    BluetoothBackend {
        id: backend
        objectName: "bluetoothBackend"
        controller: bluetoothController
    }
    BluetoothNameEdits {
        id: nameEditState
        controller: bluetoothController
        backend: backend
    }
    BluetoothAdapterEdits {
        id: adapterEditState
        controller: bluetoothController
        backend: backend
    }
    BluetoothOperationController {
        id: operationState
        controller: bluetoothController
        backend: backend
    }
}
