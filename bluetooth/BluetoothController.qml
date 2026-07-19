import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

Item {
    id: controller

    property bool uiActive: false
    property string currentWorkspaceId: ""
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    property bool detailsOpen: false
    property bool scanRequested: false
    property var adapters: []
    property var audioDevices: []
    property string audioStatus: ""
    property var pairingPrompt: null
    property var activeOperation: null
    property string pairingInput: ""
    property string status: "Loading Bluetooth devices…"
    readonly property bool actionInFlight: backend.running
    readonly property var filteredResults: results.visibleResults
    readonly property var selectedResult: results.selected()
    readonly property var selectedDevice: selectedResult ? selectedResult.payload : ({})
    readonly property var selectedAudio: audioDevices.find(function (audio) { return audio.device_key === selectedDevice.key; }) || ({})
    readonly property var activeAudioProfile: (selectedAudio.profiles || []).find(function (profile) { return profile.key === selectedAudio.active_profile_key; }) || ({})
    readonly property bool hasSelection: filteredResults.length > 0
    readonly property bool pairingPromptOpen: !!pairingPrompt
    readonly property bool canCancelOperation: !!activeOperation && (activeOperation.state === "queued" || activeOperation.state === "running")
    readonly property bool powered: adapters.some(function (adapter) { return adapter.powered; })
    readonly property bool scanning: adapters.some(function (adapter) { return adapter.discovering; })
    readonly property int closedWindowWidth: 440
    readonly property int openWindowWidth: 820
    property int surfaceWindowWidth: detailsOpen ? openWindowWidth : closedWindowWidth

    signal closeWindowRequested
    signal focusSearchRequested

    function activateUi(workspaceId) {
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
        scanRequested = false;
        refresh();
    }
    function deactivateUi() {
        if (pairingPromptOpen && pairingPrompt.response_required)
            backend.respondPairing(pairingPrompt.request_id, false, "");
        pairingPrompt = null;
        pairingInput = "";
        scanRequested = false;
        backend.setScanning(false);
        uiActive = false;
    }
    function handleTransportFailure(message) {
        scanRequested = false;
        activeOperation = null;
        status = message;
    }
    function refresh() {
        status = scanning ? "Scanning for Bluetooth devices…" : "Refreshing Bluetooth devices…";
        backend.refresh();
    }
    function applyAudioSnapshot(devices) {
        audioDevices = devices || [];
        audioStatus = "";
    }
    function applySnapshot(snapshot) {
        adapters = snapshot.adapters || [];
        results.replaceProviderResults(provider.providerId, provider.resultsForDevices(snapshot.devices || []), false);
        if (uiActive && powered && !scanning && !scanRequested) {
            scanRequested = true;
            backend.setScanning(true);
        }
        if (!powered)
            status = "Bluetooth is off";
        else if (scanning)
            status = filteredResults.length + " devices · scanning…";
        else
            status = filteredResults.length + " Bluetooth devices";
    }
    function statusForCompletedCall(id) {
        if (id === "power")
            return powered ? "Bluetooth turned on" : "Bluetooth turned off";
        if (id === "scan-start")
            return "Scanning for Bluetooth devices…";
        if (id === "scan-stop")
            return "Bluetooth scan stopped";
        if (id === "pairing-response")
            return "Pairing response sent";
        if (id.indexOf("device-") === 0)
            return "Bluetooth device updated";
        return status;
    }
    function setPower() {
        status = powered ? "Turning Bluetooth off…" : "Turning Bluetooth on…";
        scanRequested = false;
        backend.setPowered(!powered);
    }
    function toggleScan() {
        status = scanning ? "Stopping Bluetooth scan…" : "Scanning for Bluetooth devices…";
        scanRequested = true;
        backend.setScanning(!scanning);
    }
    function handleOperationAccepted(operation) {
        if (!activeOperation || activeOperation.request_id !== operation.request_id)
            activeOperation = operation;
    }
    function handleOperationEvent(operation) {
        if (!operation || !operation.request_id)
            return;
        const device = filteredResults.find(function (result) { return result.id === operation.device_key; });
        const deviceName = device ? device.title : "Bluetooth device";
        if (operation.state === "queued" || operation.state === "running") {
            activeOperation = operation;
            status = operation.operation.charAt(0).toUpperCase() + operation.operation.slice(1) + " " + deviceName + "…";
            return;
        }
        if (operation.snapshot)
            applySnapshot(operation.snapshot);
        if (activeOperation && activeOperation.request_id === operation.request_id)
            activeOperation = null;
        if (operation.state === "completed")
            status = deviceName + " updated";
        else if (operation.state === "cancelled")
            status = "Bluetooth operation cancelled";
        else
            status = (operation.error && operation.error.message) || "Bluetooth operation failed";
    }
    function cancelActiveOperation() {
        if (!canCancelOperation)
            return false;
        status = "Cancelling Bluetooth operation…";
        return backend.cancelOperation(activeOperation.request_id);
    }
    function handlePairingEvent(event) {
        const prompt = event.data || ({});
        if (event.event === "cancelled") {
            if (pairingPrompt && pairingPrompt.request_id === prompt.request_id) {
                pairingPrompt = null;
                pairingInput = "";
            }
            return;
        }
        if (event.event !== "requested" && event.event !== "display")
            return;
        pairingPrompt = prompt;
        pairingInput = "";
        status = prompt.response_required ? "Pairing confirmation required" : "Complete pairing on the Bluetooth device";
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
    function primarySelected() { return hasSelection && providers.execute(selectedResult, "", { workspaceId: currentWorkspaceId }); }
    function triggerAction(id) { return hasSelection && providers.execute(selectedResult, id, { workspaceId: currentWorkspaceId }); }
    function executeDeviceAction(actionId, device) {
        if (actionInFlight)
            return false;
        const operation = ({ pair: "pair", connect: "connect", disconnect: "disconnect", remove: "remove" })[actionId];
        if (operation) {
            status = operation.charAt(0).toUpperCase() + operation.slice(1) + " " + device.name + "…";
            return backend.deviceOperation(operation, device, {});
        }
        if (actionId === "trusted")
            return backend.deviceOperation("set-trusted", device, { trusted: !device.trusted });
        if (actionId === "wake")
            return backend.deviceOperation("set-wake-allowed", device, { wake_allowed: !device.wake_allowed });
        if (actionId === "blocked")
            return backend.deviceOperation("set-blocked", device, { blocked: !device.blocked });
        return false;
    }

    Behavior on surfaceWindowWidth { enabled: !Ui.Theme.noAnimations; NumberAnimation { duration: 180; easing.type: Easing.InOutSine } }
    Core.ProviderRegistry {
        id: providers
        BluetoothProvider { id: provider; controller: controller }
    }
    Core.ResultStore { id: results; registry: providers }
    BluetoothBackend { id: backend; controller: controller }
}
