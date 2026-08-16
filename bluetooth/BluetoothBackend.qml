import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import "BtApi.js" as BtApi

Io.DaemonBackend {
    id: backend

    required property BluetoothController controller
    property var operations
    property var finishedOperations

    daemonName: "bt-daemon"
    streams: [BtApi.streams.changed, BtApi.streams.pairing, BtApi.streams.operation,
        BtApi.streams.scan, BtApi.streams.audio]
    // Pairing authorization can arrive while the popup is hidden.
    active: true
    readonly property bool running: requestRunning || itemCount(operations) > 0
    readonly property var eventHandlers: {
        const handlers = ({});
        handlers[BtApi.streams.pairing] = backend.handlePairingEvent;
        handlers[BtApi.streams.scan] = backend.handleScanEvent;
        handlers[BtApi.streams.audio] = backend.handleAudioEvent;
        handlers[BtApi.streams.operation] = backend.handleOperationEvent;
        return handlers;
    }
    readonly property var responseHandlers: ({
        scan: function (id, data) { backend.acceptScan(data.scan, data.snapshot); },
        audio_devices: function (id, data) {
            backend.controller.applyAudioSnapshot(data.audio_devices);
            if (id === "audio-set-profile")
                backend.controller.status = "Bluetooth audio profile updated";
            else if (id === "audio-set-default")
                backend.controller.status = "Default Bluetooth audio route updated";
        },
        operation: function (id, data) { backend.acceptOperation(data.operation); },
        requests: function (id, data) { backend.restoreRequestState(data.requests); }
    })

    function itemCount(values) { return Object.keys(values || ({})).length; }
    function resetTransportState() {
        pending = ({}); operations = ({}); finishedOperations = ({});
    }
    function restoreRequestState(requests) {
        const operationSnapshot = (requests || {}).operations || ({});
        const active = ({});
        (operationSnapshot.active || []).forEach(function (operation) {
            if (operation && operation.request_id)
                active[operation.request_id] = operation;
        });
        const recent = ({});
        (operationSnapshot.recent || []).forEach(function (operation) {
            if (operation && operation.request_id)
                recent[operation.request_id] = true;
        });
        operations = active;
        finishedOperations = recent;
        controller.applyRequestSnapshot(requests || ({}));
    }
    function cancellationStatus(id) {
        if (id.indexOf("cancel-operation-") === 0)
            return "Cancelling Bluetooth operation…";
        return "";
    }
    function finish(id, envelope, transportError) {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            "bt-api", 1, daemonName, "Bluetooth operation failed");
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
    function compatibleEvent(event: var): bool {
        if (!Core.ApiEnvelope.compatibilityError(event, "bt-api", 1, "bt-daemon"))
            return true;
        console.warn("shelllist bluetooth event rejected reason=incompatible-envelope");
        return false;
    }
    function recoverEventGap(): void {
        controller.status = "Bluetooth events were missed; recovering current state…";
        recoverRequests();
        if (!isPending("snapshot")) refresh();
    }
    function processEvent(event: var): void {
        if (!compatibleEvent(event))
            return;
        if (event.event === "lagged") {
            recoverEventGap();
            return;
        }
        if (!dispatchStreamEvent(event))
            applyUnhandledEvent(event);
    }
    function handleEvent(event: var): void {
        try {
            processEvent(event);
        } catch (error) {
            const stream = event && event.stream ? event.stream : "unknown";
            console.error("shelllist bluetooth event failed stream=" + stream + " error=" + error);
            controller.status = "Could not process bt-daemon event: " + error;
        }
    }
    function handlePairingEvent(event) { controller.handlePairingEvent(event); }
    function handleScanEvent(event) { controller.handleScanEvent(event.data || ({})); }
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
    function cancelActive(kind, requestId, activeItems) {
        if (!requestId || !activeItems[requestId]) {
            console.warn("shelllist bluetooth " + kind + " cancellation rejected request_id="
                + (requestId || "") + " reason=not-active");
            return false;
        }
        const accepted = cancel(requestId, "cancel-" + kind + "-" + requestId);
        if (accepted)
            console.info("shelllist bluetooth " + kind + " cancellation requested request_id=" + requestId);
        return accepted;
    }
    function setAudioProfile(deviceKey, profileKey) { return call("audio-set-profile", BtApi.methods.audioSetProfile, { device_key: deviceKey, profile_key: profileKey }); }
    function recoverRequests() {
        if (isPending("requests")) return false;
        return call("requests", BtApi.methods.requestsSnapshot, {});
    }
    function setPowered(powered, adapterKey) { return call("power", BtApi.methods.setPowered, { adapter_key: adapterKey || null, powered: powered }); }
    function setScanning(enabled, adapterKey) {
        if (!enabled && controller.activeScan && controller.activeScan.request_id) {
            const requestId = controller.activeScan.request_id;
            const accepted = cancel(requestId, "cancel-scan-" + requestId);
            if (accepted)
                console.info("shelllist bluetooth scan cancellation requested request_id=" + requestId);
            return accepted;
        }
        return call("scan-start", BtApi.methods.scan, { enabled: true, adapter_key: adapterKey || null, timeout_ms: 15000 });
    }
    function adapterOperation(operation, adapter, values) {
        return call("adapter-" + operation, BtApi.methods.adapterOperation,
            Object.assign({ key: adapter.key, operation: operation }, values || ({})));
    }
    function updateManagement(values) {
        return call("management-update", BtApi.methods.managementUpdate, values || ({}));
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

    onResponseReceived: function (id, envelope, transportError) { finish(id, envelope, transportError); }
    onEventReceived: function (event) { handleEvent(event); }
    onSendFailed: function (id, message) { controller.status = message; }
    onTransportFailed: function (message) {
        resetTransportState();
        controller.handleTransportFailure(message);
    }
    onTransportReady: {
        recoverRequests();
        if (!isPending("snapshot")) refresh();
    }
}
