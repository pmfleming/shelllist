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
    readonly property bool actionInFlight: backend.running
    readonly property var filteredResults: results.visibleResults
    readonly property var selectedResult: results.selected()
    readonly property var selectedDevice: selectedResult ? selectedResult.payload : ({})
    readonly property var selectedAdapter: adapters.find(function (adapter) { return adapter.key === preferredAdapterKey; }) || adapters.find(function (adapter) { return adapter.key === selectedDevice.adapter_key; }) || adapters[0] || ({})
    readonly property var selectedAudio: audioDevices.find(function (audio) { return audio.device_key === selectedDevice.key; }) || ({})
    readonly property var activeAudioProfile: (selectedAudio.profiles || []).find(function (profile) { return profile.key === selectedAudio.active_profile_key; }) || ({})
    readonly property bool hasSelection: filteredResults.length > 0
    readonly property bool pairingPromptOpen: !!pairingPrompt
    readonly property bool incomingTransferPromptOpen: !!incomingTransferPrompt
    readonly property bool modalPromptOpen: pairingPromptOpen || incomingTransferPromptOpen
    readonly property bool canCancelTransfer: !!activeTransfer && !["complete", "cancelled", "error"].includes(activeTransfer.status)
    readonly property bool canCancelOperation: !!activeOperation && (activeOperation.state === "queued" || activeOperation.state === "running")
    readonly property bool powered: selectedAdapter.key ? !!selectedAdapter.powered : adapters.some(function (adapter) { return adapter.powered; })
    readonly property bool scanning: !!activeScan
    readonly property int closedWindowWidth: 440
    readonly property int openWindowWidth: 820
    property int surfaceWindowWidth: detailsOpen ? openWindowWidth : closedWindowWidth

    signal closeWindowRequested
    signal focusSearchRequested
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
    function applySnapshot(snapshot) {
        adapters = snapshot.adapters || [];
        if (adapters.length > 0 && !adapters.some(function (adapter) { return adapter.key === preferredAdapterKey; }))
            preferredAdapterKey = adapters[0].key;
        results.replaceProviderResults(provider.providerId, provider.resultsForDevices(snapshot.devices || []), false);
        if (uiActive && powered && !scanning && !scanRequested) {
            scanRequested = true;
            backend.setScanning(true, selectedAdapter.key);
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
        if (scan.state === "completed")
            status = filteredResults.length + " Bluetooth devices · scan complete";
        else if (scan.state === "cancelled")
            status = "Bluetooth scan stopped";
        else if (scan.state === "failed")
            status = (scan.error && scan.error.message) || "Bluetooth scan failed";
    }
    function sendFile(path) {
        if (!hasSelection || !path || actionInFlight || !obexCapabilities.outgoing_object_push)
            return false;
        status = "Starting file transfer to " + selectedDevice.name + "…";
        return backend.sendFile(selectedDevice.key, path);
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
        if (["complete", "cancelled", "error"].includes(transfer.status)) {
            if (activeTransfer && activeTransfer.request_id === transfer.request_id)
                activeTransfer = null;
            if (transfer.status === "complete")
                status = transfer.direction === "incoming" ? transfer.file_name + " saved in Downloads" : transfer.file_name + " sent";
            else if (transfer.status === "cancelled")
                status = "File transfer cancelled";
            else
                status = (transfer.error && transfer.error.message) || "File transfer failed";
            return;
        }
        activeTransfer = transfer;
        const percentage = transfer.size > 0 ? Math.floor(transfer.transferred * 100 / transfer.size) : 0;
        const verb = transfer.direction === "incoming" ? "Receiving " : "Sending ";
        status = verb + transfer.file_name + (transfer.size > 0 ? " · " + percentage + "%" : "…");
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
    function adapterOperation(operation, values) {
        if (!selectedAdapter.key || actionInFlight)
            return false;
        status = "Updating Bluetooth adapter…";
        return backend.adapterOperation(operation, selectedAdapter, values || ({}));
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

    Behavior on surfaceWindowWidth { enabled: !Ui.Theme.noAnimations; NumberAnimation { duration: 180; easing.type: Easing.InOutSine } }
    Core.ProviderRegistry {
        id: providers
        BluetoothProvider { id: provider; controller: controller }
    }
    Core.ResultStore { id: results; registry: providers }
    BluetoothBackend { id: backend; controller: controller }
}
