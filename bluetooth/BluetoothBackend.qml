import QtQuick
import "BtApi.js" as BtApi

Item {
    id: backend

    required property BluetoothController controller
    property var pending
    property var operations
    property var finishedOperations
    property var transfers
    property var finishedTransfers
    property var scans

    // Incoming OBEX authorization can arrive while the popup is hidden.
    readonly property bool active: true
    readonly property bool running: itemCount(pending) > 0 || itemCount(operations) > 0 || itemCount(transfers) > 0
    readonly property var eventHandlers: {
        const handlers = ({});
        handlers[BtApi.streams.pairing] = backend.handlePairingEvent;
        handlers[BtApi.streams.scan] = backend.handleScanEvent;
        handlers[BtApi.streams.obex] = backend.handleTransferEvent;
        handlers[BtApi.streams.audio] = backend.handleAudioEvent;
        handlers[BtApi.streams.operation] = backend.handleOperationEvent;
        return handlers;
    }

    function itemCount(values) { return Object.keys(values || ({})).length; }
    function resetTransportState() {
        pending = ({}); operations = ({}); finishedOperations = ({});
        transfers = ({}); finishedTransfers = ({}); scans = ({});
    }
    function copyWithout(values, key) {
        const result = Object.assign({}, values);
        delete result[key];
        return result;
    }
    function copyWith(values, key, value) {
        const result = Object.assign({}, values);
        result[key] = value;
        return result;
    }
    function lifecycleState(item, activeItems, finishedItems, state, terminalStates) {
        const id = item.request_id;
        if (!id)
            return { active: activeItems, finished: finishedItems };
        if (!terminalStates.includes(state))
            return { active: copyWith(activeItems, id, item), finished: finishedItems };
        return {
            active: copyWithout(activeItems, id),
            finished: activeItems[id] ? finishedItems : copyWith(finishedItems, id, true)
        };
    }
    function isPending(id) { return !!pending[id]; }
    function call(id, method, params) {
        if (isPending(id)) {
            console.warn("shelllist bluetooth request rejected id=" + id + " reason=already-pending");
            return false;
        }
        pending = copyWith(pending, id, true);
        console.info("shelllist bluetooth request started id=" + id + " method=" + method);
        try {
            client.call(id, method, params);
            return true;
        } catch (error) {
            pending = copyWithout(pending, id);
            console.error("shelllist bluetooth request failed id=" + id + " stage=send error=" + error);
            controller.status = "Could not send Bluetooth request " + id + ": " + error;
            return false;
        }
    }
    function isSessionControl(id) { return id === "session-subscribe" || id.indexOf("cancel-subscription-") === 0 || id.indexOf("shutdown-") === 0; }
    function responseError(envelope, transportError) {
        if (transportError.length > 0)
            return transportError;
        if (!envelope || envelope.protocol !== "bt-api" || envelope.version !== 1)
            return "bt-daemon returned an incompatible response";
        if (!envelope.ok)
            return (envelope.error && envelope.error.message) || "Bluetooth operation failed";
        return "";
    }
    function cancellationStatus(id) {
        if (id.indexOf("cancel-transfer-") === 0)
            return "Cancelling file transfer…";
        if (id.indexOf("cancel-operation-") === 0)
            return "Cancelling Bluetooth operation…";
        return "";
    }
    function finish(id, envelope, transportError) {
        if (isSessionControl(id))
            return;
        pending = copyWithout(pending, id);
        const error = responseError(envelope, transportError);
        if (error.length > 0) {
            console.error("shelllist bluetooth request failed id=" + id + " stage=response error=" + error);
            controller.status = error;
            return;
        }
        const cancellation = cancellationStatus(id);
        if (cancellation.length > 0) {
            console.info("shelllist bluetooth cancellation accepted id=" + id);
            controller.status = cancellation;
            return;
        }
        try {
            applyResponse(id, envelope.data || ({}));
            console.info("shelllist bluetooth request completed id=" + id);
        } catch (applyError) {
            console.error("shelllist bluetooth request failed id=" + id + " stage=parse error=" + applyError);
            controller.status = "Could not parse bt-daemon " + id + " response: " + applyError;
        }
    }
    function applyResponse(id, data) {
        if (data.scan)
            return acceptScan(data.scan, data.snapshot);
        if (data.transfer)
            return acceptTransfer(data.transfer);
        if (data.obex)
            return controller.applyObexSnapshot(data.obex);
        if (data.audio_devices) {
            controller.applyAudioSnapshot(data.audio_devices);
            if (id === "audio-set-profile")
                controller.status = "Bluetooth audio profile updated";
            return;
        }
        if (data.operation)
            return acceptOperation(data.operation);
        if (data.snapshot)
            controller.applySnapshot(data.snapshot);
        if (id !== "snapshot")
            controller.status = controller.statusForCompletedCall(id);
    }
    function acceptScan(scan, snapshot) {
        scans = copyWith(scans, scan.request_id, scan);
        controller.handleScanEvent(scan);
        if (snapshot)
            controller.applySnapshot(snapshot);
    }
    function acceptTransfer(transfer) {
        if (finishedTransfers[transfer.request_id]) {
            finishedTransfers = copyWithout(finishedTransfers, transfer.request_id);
            return;
        }
        transfers = copyWith(transfers, transfer.request_id, transfer);
        controller.handleObexTransfer(transfer);
    }
    function acceptOperation(operation) {
        if (finishedOperations[operation.request_id]) {
            finishedOperations = copyWithout(finishedOperations, operation.request_id);
            return;
        }
        operations = copyWith(operations, operation.request_id, operation);
        controller.handleOperationAccepted(operation);
    }

    function handleEvent(event) {
        try {
            if (!event || event.protocol !== "bt-api" || event.version !== 1) {
                console.warn("shelllist bluetooth event rejected reason=incompatible-envelope");
                return;
            }
            const handler = eventHandlers[event.stream];
            if (handler) {
                handler(event);
                return;
            }
            if (event.event === "unavailable") {
                controller.status = (event.error && event.error.message) || "BlueZ is unavailable";
                return;
            }
            if (event.data && event.data.snapshot)
                controller.applySnapshot(event.data.snapshot);
            else
                console.warn("shelllist bluetooth event ignored stream=" + (event.stream || "unknown") + " event=" + (event.event || "unknown"));
        } catch (error) {
            console.error("shelllist bluetooth event failed stream=" + (event && event.stream ? event.stream : "unknown") + " error=" + error);
            controller.status = "Could not process bt-daemon event: " + error;
        }
    }
    function handlePairingEvent(event) { controller.handlePairingEvent(event); }
    function handleScanEvent(event) {
        const scan = event.data || ({});
        if (scan.request_id)
            scans = ["completed", "failed", "cancelled"].includes(scan.state) ? copyWithout(scans, scan.request_id) : copyWith(scans, scan.request_id, scan);
        controller.handleScanEvent(scan);
    }
    function handleTransferEvent(event) {
        const transfer = event.data || ({});
        const next = lifecycleState(transfer, transfers, finishedTransfers, transfer.status, ["complete", "cancelled", "error"]);
        transfers = next.active;
        finishedTransfers = next.finished;
        controller.handleObexTransfer(transfer);
    }
    function handleAudioEvent(event) {
        if (event.event === "unavailable")
            controller.audioStatus = (event.error && event.error.message) || "Bluetooth audio is unavailable";
        else
            controller.applyAudioSnapshot((event.data && event.data.audio_devices) || []);
    }
    function handleOperationEvent(event) {
        const operation = event.data || ({});
        const next = lifecycleState(operation, operations, finishedOperations, operation.state, ["completed", "failed", "cancelled"]);
        operations = next.active;
        finishedOperations = next.finished;
        controller.handleOperationEvent(operation);
    }

    Component.onCompleted: resetTransportState()

    function refresh() { return call("snapshot", BtApi.methods.snapshot, {}); }
    function refreshObex() { return call("obex-snapshot", BtApi.methods.obexSnapshot, {}); }
    function sendFile(deviceKey, path) { return call("obex-send", BtApi.methods.obexSend, { device_key: deviceKey, path: path }); }
    function respondObex(requestId, accept) { return call("obex-response", BtApi.methods.obexRespond, { request_id: requestId, accept: !!accept }); }
    function cancelTransfer(requestId) {
        if (!requestId || !transfers[requestId]) {
            console.warn("shelllist bluetooth transfer cancellation rejected request_id=" + (requestId || "") + " reason=not-active");
            return false;
        }
        try {
            client.cancel("cancel-transfer-" + requestId, requestId);
            console.info("shelllist bluetooth transfer cancellation requested request_id=" + requestId);
            return true;
        } catch (error) {
            console.error("shelllist bluetooth transfer cancellation failed request_id=" + requestId + " error=" + error);
            controller.status = "Could not cancel Bluetooth transfer: " + error;
            return false;
        }
    }
    function refreshAudio() { return call("audio-snapshot", BtApi.methods.audioSnapshot, {}); }
    function setAudioProfile(deviceKey, profileKey) { return call("audio-set-profile", BtApi.methods.audioSetProfile, { device_key: deviceKey, profile_key: profileKey }); }
    function setPowered(powered, adapterKey) { return call("power", BtApi.methods.setPowered, { adapter_key: adapterKey || null, powered: powered }); }
    function setScanning(enabled, adapterKey) {
        if (!enabled && controller.activeScan && controller.activeScan.request_id) {
            const requestId = controller.activeScan.request_id;
            try {
                client.cancel("cancel-scan-" + requestId, requestId);
                console.info("shelllist bluetooth scan cancellation requested request_id=" + requestId);
                return true;
            } catch (error) {
                console.error("shelllist bluetooth scan cancellation failed request_id=" + requestId + " error=" + error);
                controller.status = "Could not cancel Bluetooth scan: " + error;
                return false;
            }
        }
        return call("scan-start", BtApi.methods.scan, { enabled: true, adapter_key: adapterKey || null, timeout_ms: 15000 });
    }
    function adapterOperation(operation, adapter, values) {
        return call("adapter-" + operation, BtApi.methods.adapterOperation,
            Object.assign({ key: adapter.key, operation: operation }, values || ({})));
    }
    function cancelOperation(requestId) {
        if (!requestId || !operations[requestId]) {
            console.warn("shelllist bluetooth operation cancellation rejected request_id=" + (requestId || "") + " reason=not-active");
            return false;
        }
        try {
            client.cancel("cancel-operation-" + requestId, requestId);
            console.info("shelllist bluetooth operation cancellation requested request_id=" + requestId);
            return true;
        } catch (error) {
            console.error("shelllist bluetooth operation cancellation failed request_id=" + requestId + " error=" + error);
            controller.status = "Could not cancel Bluetooth operation: " + error;
            return false;
        }
    }
    function respondPairing(requestId, accept, value) {
        const params = { request_id: requestId, accept: !!accept };
        if (value !== undefined && value !== null)
            params.value = value;
        return call("pairing-response", BtApi.methods.pairingRespond, params);
    }
    function deviceOperation(operation, device, values) {
        return call("device-" + operation, BtApi.methods.deviceOperation,
            Object.assign({ key: device.key, operation: operation }, values || ({})));
    }

    BtDaemonClient {
        id: client
        active: backend.active
        onResponse: function (id, envelope, transportError) { backend.finish(id, envelope, transportError); }
        onEventReceived: function (event) { backend.handleEvent(event); }
        onTransportFailed: function (message) {
            backend.resetTransportState();
            backend.controller.handleTransportFailure(message);
        }
    }
}
