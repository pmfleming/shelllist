import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import "BtApi.js" as BtApi

Item {
    id: backend

    required property BluetoothController controller
    property var pending
    property var operations
    property var finishedOperations
    property var transfers
    property var finishedTransfers

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
    readonly property var responseHandlers: ({
        scan: function (id, data) { backend.acceptScan(data.scan, data.snapshot); },
        transfer: function (id, data) { backend.acceptTransfer(data.transfer); },
        obex: function (id, data) { backend.controller.applyObexSnapshot(data.obex); },
        audio_devices: function (id, data) {
            backend.controller.applyAudioSnapshot(data.audio_devices);
            if (id === "audio-set-profile")
                backend.controller.status = "Bluetooth audio profile updated";
        },
        operation: function (id, data) { backend.acceptOperation(data.operation); }
    })

    function itemCount(values) { return Object.keys(values || ({})).length; }
    function resetTransportState() {
        pending = ({}); operations = ({}); finishedOperations = ({});
        transfers = ({}); finishedTransfers = ({});
    }
    function isPending(id) { return !!pending[id]; }
    function call(id, method, params) {
        if (isPending(id)) {
            console.warn("shelllist bluetooth request rejected id=" + id + " reason=already-pending");
            return false;
        }
        pending = BtApi.copyWith(pending, id, true);
        console.info("shelllist bluetooth request started id=" + id + " method=" + method);
        try {
            client.call(id, method, params);
            return true;
        } catch (error) {
            pending = BtApi.copyWithout(pending, id);
            console.error("shelllist bluetooth request failed id=" + id + " stage=send error=" + error);
            controller.status = "Could not send Bluetooth request " + id + ": " + error;
            return false;
        }
    }
    function isSessionControl(id) { return id === "session-subscribe" || id.indexOf("cancel-subscription-") === 0 || id.indexOf("shutdown-") === 0; }
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
        pending = BtApi.copyWithout(pending, id);
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            "bt-api", 1, "bt-daemon", "Bluetooth operation failed");
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
        const kind = BtApi.responseKind(data);
        if (kind.length > 0) {
            responseHandlers[kind](id, data);
            return;
        }
        if (data.snapshot)
            controller.applySnapshot(data.snapshot);
        if (id !== "snapshot")
            controller.status = controller.statusForCompletedCall(id);
    }
    function acceptScan(scan, snapshot) {
        controller.handleScanEvent(scan);
        if (snapshot)
            controller.applySnapshot(snapshot);
    }
    function acceptTransfer(transfer) {
        if (finishedTransfers[transfer.request_id]) {
            finishedTransfers = BtApi.copyWithout(finishedTransfers, transfer.request_id);
            return;
        }
        transfers = BtApi.copyWith(transfers, transfer.request_id, transfer);
        controller.handleObexTransfer(transfer);
    }
    function acceptOperation(operation) {
        if (finishedOperations[operation.request_id]) {
            finishedOperations = BtApi.copyWithout(finishedOperations, operation.request_id);
            return;
        }
        operations = BtApi.copyWith(operations, operation.request_id, operation);
        controller.handleOperationAccepted(operation);
    }

    function dispatchStreamEvent(event) {
        const handler = eventHandlers[event.stream];
        if (!handler)
            return false;
        handler(event);
        return true;
    }
    function applyUnhandledEvent(event) {
        if (event.event === "unavailable") {
            controller.status = (event.error && event.error.message) || "BlueZ is unavailable";
            return;
        }
        if (event.data && event.data.snapshot) {
            controller.applySnapshot(event.data.snapshot);
            return;
        }
        console.warn("shelllist bluetooth event ignored stream=" + (event.stream || "unknown")
            + " event=" + (event.event || "unknown"));
    }
    function handleEvent(event) {
        try {
            if (Core.ApiEnvelope.compatibilityError(event, "bt-api", 1, "bt-daemon")) {
                console.warn("shelllist bluetooth event rejected reason=incompatible-envelope");
                return;
            }
            if (!dispatchStreamEvent(event))
                applyUnhandledEvent(event);
        } catch (error) {
            const stream = event && event.stream ? event.stream : "unknown";
            console.error("shelllist bluetooth event failed stream=" + stream + " error=" + error);
            controller.status = "Could not process bt-daemon event: " + error;
        }
    }
    function handlePairingEvent(event) { controller.handlePairingEvent(event); }
    function handleScanEvent(event) { controller.handleScanEvent(event.data || ({})); }
    function handleTransferEvent(event) {
        const transfer = event.data || ({});
        const next = BtApi.lifecycleState(transfer, transfers, finishedTransfers, transfer.status, ["complete", "cancelled", "error"]);
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
        const next = BtApi.lifecycleState(operation, operations, finishedOperations, operation.state, ["completed", "failed", "cancelled"]);
        operations = next.active;
        finishedOperations = next.finished;
        controller.handleOperationEvent(operation);
    }

    Component.onCompleted: resetTransportState()

    function refresh() { return call("snapshot", BtApi.methods.snapshot, {}); }
    function refreshObex() { return call("obex-snapshot", BtApi.methods.obexSnapshot, {}); }
    function sendFile(deviceKey, path) { return call("obex-send", BtApi.methods.obexSend, { device_key: deviceKey, path: path }); }
    function respondObex(requestId, accept) { return call("obex-response", BtApi.methods.obexRespond, { request_id: requestId, accept: !!accept }); }
    function cancelActive(kind, requestId, activeItems) {
        if (!requestId || !activeItems[requestId]) {
            console.warn("shelllist bluetooth " + kind + " cancellation rejected request_id="
                + (requestId || "") + " reason=not-active");
            return false;
        }
        try {
            client.cancel("cancel-" + kind + "-" + requestId, requestId);
            console.info("shelllist bluetooth " + kind + " cancellation requested request_id=" + requestId);
            return true;
        } catch (error) {
            console.error("shelllist bluetooth " + kind + " cancellation failed request_id=" + requestId + " error=" + error);
            controller.status = "Could not cancel Bluetooth " + kind + ": " + error;
            return false;
        }
    }
    function cancelTransfer(requestId) { return cancelActive("transfer", requestId, transfers); }
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
    function cancelOperation(requestId) { return cancelActive("operation", requestId, operations); }
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

    Io.JsonlDaemonClient {
        id: client
        daemonName: "bt-daemon"
        recoverProtocolErrors: true
        streams: [BtApi.streams.changed, BtApi.streams.pairing, BtApi.streams.operation,
            BtApi.streams.scan, BtApi.streams.audio, BtApi.streams.obex]
        active: backend.active
        onResponse: function (id, envelope, transportError) { backend.finish(id, envelope, transportError); }
        onEventReceived: function (event) { backend.handleEvent(event); }
        onTransportFailed: function (message) {
            backend.resetTransportState();
            backend.controller.handleTransportFailure(message);
        }
    }
}
