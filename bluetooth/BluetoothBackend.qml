import QtQuick
import Shelllist.Io as Io
import "BtApi.js" as BtApi
import "BluetoothFlow.js" as BluetoothFlow

Io.DaemonBackend {
    id: backend

    required property BluetoothController controller
    readonly property alias operations: operationRecovery.operations
    readonly property alias finishedOperations: operationRecovery.finishedOperations
    readonly property bool foregroundRequestRunning: Object.keys(pending).some(id => !id.startsWith("operation-status-"))

    BluetoothOperationRecovery {
        id: operationRecovery
        objectName: "bluetoothOperationRecovery"
        backend: backend
        controller: backend.controller
    }
    property string nameRequestKey: ""

    Io.SnapshotCursor { id: radioCursor; objectName: "bluetoothRadioCursor" }
    Io.SnapshotCursor { id: audioCursor; objectName: "bluetoothAudioCursor" }

    daemonName: "bt-daemon"
    expectedProtocol: BtApi.protocol
    expectedVersion: BtApi.version
    streams: BtApi.subscribedStreams
    // Pairing authorization can arrive while the popup is hidden.
    active: true
    readonly property bool running: requestRunning || Object.keys(operations).length > 0
    readonly property var eventHandlers: {
        const handlers = ({});
        handlers[BtApi.streams.pairing] = controller.handlePairingEvent;
        handlers[BtApi.streams.scan] = backend.handleScanEvent;
        handlers[BtApi.streams.audio] = backend.handleAudioEvent;
        handlers[BtApi.streams.operation] = backend.handleOperationEvent;
        return handlers;
    }
    readonly property var responseHandlers: ({
            scan: function (id, data) {
                backend.controller.handleScanEvent(data.scan);
            },
            audio_devices: function (id, data) {
                // Mutation observations have no publication watermark. Keep the
                // acknowledgement, but reconcile state through its cached read.
                backend.refreshAudio();
                if (id === "audio-set-default")
                    backend.controller.status = "Default Bluetooth audio route updated";
            },
            operation: function (id, data) {
                backend.acceptOperation(data.operation);
            },
            requests: function (id, data) {
                backend.restoreRequestState(data.requests);
            }
        })

    function resetTransportState() {
        nameRequestKey = "";
        radioCursor.reset();
        audioCursor.reset();
        pending = ({});
        operationRecovery.reset();
    }
    function restoreRequestState(requests) {
        operationRecovery.restore((requests || {}).operations);
        controller.applyRequestSnapshot(requests || ({}));
    }
    function finishDeviceRequest(id: string, error: string): void {
        if (id === "device-set-alias") {
            if (error)
                controller.nameEdits.rejected(nameRequestKey, error);
            nameRequestKey = "";
        }
        if (id === "pairing-response")
            controller.finishPairingResponse(error.length === 0);
    }
    function finishSnapshot(id: string, envelope: var, transportError: string, error: string): void {
        if (transportError) {
            showFailure(id, error);
            return;
        }
        try {
            if (!envelope || envelope.protocol !== BtApi.protocol || envelope.version !== BtApi.version
                    || typeof envelope.ok !== "boolean")
                throw new Error("Incompatible Bluetooth snapshot envelope");
            const phase = !error ? "available" : envelope?.error?.code === "snapshot-loading" ? "loading" : "unavailable";
            acceptState(envelope?.data, phase, error, id === "audio-snapshot");
        } catch (snapshotError) {
            showFailure(id, "Invalid Bluetooth snapshot: " + snapshotError);
        }
    }
    function finish(id: string, envelope: var, transportError: string): void {
        const error = responseError(envelope, transportError, "Bluetooth operation failed");
        if (operationRecovery.finishStatus(id, envelope?.data?.operation_status, error))
            return;
        if (id.startsWith("operation-status-"))
            return; // Unowned/retired status replies cannot enter mutation handling.
        if (id === "snapshot" || id === "audio-snapshot") {
            finishSnapshot(id, envelope, transportError, error);
            return;
        }
        finishDeviceRequest(id, error);
        if (id === "adapter-batch") {
            controller.adapterEdits.receive(envelope?.data || ({}), error);
            return;
        }
        if (error.length > 0) {
            console.error("shelllist bluetooth request failed id=" + id + " stage=response error=" + error);
            showFailure(id, error);
            return;
        }
        if (id.startsWith("cancel-operation-")) {
            console.info("shelllist bluetooth cancellation accepted id=" + id);
            controller.status = "Cancelling Bluetooth operation…";
            return;
        }
        try {
            applyResponse(id, envelope.data || ({}));
            if (id === "audio-set-profile")
                controller.status = BluetoothFlow.audioProfileStatus(envelope.data?.profile_outcome);
            console.info("shelllist bluetooth request completed id=" + id);
        } catch (applyError) {
            console.error("shelllist bluetooth request failed id=" + id + " stage=parse error=" + applyError);
            showFailure(id, "Could not parse bt-daemon " + id + " response: " + applyError);
        }
    }
    function showFailure(id: string, message: string): void {
        if (id === "snapshot" || id === "scan-start")
            controller.listError = message;
        controller.status = message;
    }
    function applyResponse(id, data) {
        const kind = BtApi.responseKind(data);
        if (kind.length > 0) {
            responseHandlers[kind](id, data);
            return;
        }
        if (data.snapshot)
            reconcileSnapshot();
        if (id !== "snapshot")
            controller.status = controller.statusForCompletedCall(id);
    }
    function reconcileSnapshot() {
        return !isPending("snapshot") && refresh();
    }
    function acceptState(data, phase, message, audio) {
        if (!BtApi.objectValue(data))
            throw new Error("Missing native snapshot metadata; matching daemon required");
        if (phase === "available" && !BtApi.validSnapshot(data, audio))
            throw new Error(audio ? "Malformed Bluetooth audio snapshot" : "Malformed Bluetooth radio snapshot");
        const cursor = audio ? audioCursor : radioCursor;
        const accepted = cursor.accept(data.state, function() {
            if (audio) {
                if (phase === "available")
                    controller.applyAudioSnapshot(data.audio_devices);
                else
                    controller.invalidateAudio(message || "Bluetooth audio is unavailable");
            } else if (phase === "available") {
                controller.applySnapshot(data.snapshot);
            } else {
                controller.invalidateBluetooth(message || "Bluetooth is unavailable");
                if (phase === "loading") {
                    controller.listError = "";
                    controller.backendLoading = true;
                }
            }
        });
        if (cursor.error)
            throw new Error(cursor.error);
        return accepted;
    }
    function acceptOperation(operation) {
        operationRecovery.apply(operation, true, false);
    }

    function applyUnhandledEvent(event) {
        if (event.stream === BtApi.streams.changed) {
            if (!["subscribed", "changed", "loading", "unavailable"].includes(event.event))
                throw new Error("Unknown Bluetooth snapshot event");
            const phase = event.event === "loading" || event.event === "unavailable" ? event.event : "available";
            acceptState(event.data, phase, event.error?.message || "", false);
            return;
        }
        console.warn("shelllist bluetooth event ignored stream=" + (event.stream || "unknown") + " event=" + (event.event || "unknown"));
    }
    function recoverEventGap(stream: string): void {
        controller.status = "Bluetooth events were missed; recovering current state…";
        if (stream === BtApi.streams.operation) {
            // Operation loss has its own owned read. Do not replace unrelated
            // private prompts or discovery leases with an aggregate observation.
            operationRecovery.poll();
            return;
        }
        recoverRequests();
        if (!isPending("snapshot"))
            refresh();
    }
    function handleEvent(event: var): void {
        try {
            if (!routeEvent(event, eventHandlers))
                applyUnhandledEvent(event);
        } catch (error) {
            const stream = event && event.stream ? event.stream : "unknown";
            console.error("shelllist bluetooth event failed stream=" + stream + " error=" + error);
            controller.status = "Could not process bt-daemon event: " + error;
        }
    }
    function handleScanEvent(event) {
        controller.handleScanEvent(event.data || ({}));
    }
    function handleAudioEvent(event) {
        if (!["subscribed", "changed", "unavailable"].includes(event.event))
            throw new Error("Unknown Bluetooth audio event");
        acceptState(event.data, event.event === "unavailable" ? "unavailable" : "available", event.error?.message || "", true);
    }
    function handleOperationEvent(event) {
        operationRecovery.apply(event.data, false, false);
    }

    Component.onCompleted: resetTransportState()

    function refresh() {
        controller.listError = "";
        return call("snapshot", BtApi.methods.snapshot, {});
    }
    function refreshAudio() {
        return !isPending("audio-snapshot") && call("audio-snapshot", BtApi.methods.audioSnapshot, {});
    }
    function cancelActive(kind, requestId, activeItems) {
        if (!requestId || !activeItems[requestId]) {
            console.warn("shelllist bluetooth " + kind + " cancellation rejected request_id=" + (requestId || "") + " reason=not-active");
            return false;
        }
        const accepted = cancelWithId(requestId, "cancel-" + kind + "-" + requestId);
        if (accepted)
            console.info("shelllist bluetooth " + kind + " cancellation requested request_id=" + requestId);
        return accepted;
    }
    function updateDevicePolicy(deviceKey, values) {
        return call("device-policy", BtApi.methods.devicePolicyUpdate, Object.assign({
            key: deviceKey
        }, values));
    }
    function setAudioDefault(deviceKey, endpointKey) {
        return call("audio-set-default", BtApi.methods.audioSetDefault, {
            device_key: deviceKey,
            endpoint_key: endpointKey
        });
    }
    function setAudioProfile(deviceKey, profileKey) {
        if (isPending("audio-set-profile"))
            return false;
        return call("audio-set-profile", BtApi.methods.audioSetProfile, {
            device_key: deviceKey,
            profile_key: profileKey,
            remember: true
        });
    }
    function recoverRequests() {
        if (isPending("requests"))
            return false;
        return call("requests", BtApi.methods.requestsSnapshot, {});
    }
    function setPowered(powered, adapterKey) {
        return call("power", BtApi.methods.setPowered, {
            adapter_key: adapterKey || null,
            powered: powered
        });
    }
    function setScanning(enabled, adapterKey) {
        if (!enabled && controller.activeScan && controller.activeScan.request_id) {
            const requestId = controller.activeScan.request_id;
            const accepted = cancelWithId(requestId, "cancel-scan-" + requestId);
            if (accepted)
                console.info("shelllist bluetooth scan cancellation requested request_id=" + requestId);
            return accepted;
        }
        controller.listError = "";
        return call("scan-start", BtApi.methods.scan, {
            enabled: true,
            adapter_key: adapterKey || null,
            timeout_ms: 15000
        });
    }
    function updateAdapter(key, changes) {
        if (isPending("adapter-batch"))
            return false;
        return call("adapter-batch", BtApi.methods.adapterUpdate, { key: key, changes: changes });
    }
    function adapterOperation(operation, adapter, values) {
        const id = "adapter-" + operation;
        if (isPending(id))
            return false;
        return call(id, BtApi.methods.adapterOperation, Object.assign({
            key: adapter.key,
            operation: operation
        }, values || ({})));
    }
    function updateManagement(values) {
        return call("management-update", BtApi.methods.managementUpdate, values || ({}));
    }
    function cancelOperation(requestId) {
        return cancelActive("operation", requestId, operations);
    }
    function cancelPairingPrompt(requestId: string): bool {
        const id = "pairing-cancel-" + requestId;
        if (isPending(id))
            return false;
        return call(id, BtApi.methods.pairingRespond, {
            request_id: requestId,
            accept: false
        });
    }
    function respondPairing(requestId, accept, value) {
        const params = {
            request_id: requestId,
            accept: !!accept
        };
        if (value !== undefined && value !== null)
            params.value = value;
        return call("pairing-response", BtApi.methods.pairingRespond, params);
    }
    function deviceOperation(operation, device, values) {
        if (operation === "set-alias") {
            if (isPending("device-set-alias"))
                return false;
            nameRequestKey = device.key;
        }
        return call("device-" + operation, BtApi.methods.deviceOperation, Object.assign({
            key: device.key,
            operation: operation
        }, values || ({})));
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventGapDetected: function (stream) { recoverEventGap(stream); }
    onEventReceived: function (event) {
        handleEvent(event);
    }
    onSendFailed: function (id, message) { showFailure(id, message); }
    onTransportFailed: function (message) {
        resetTransportState();
        controller.handleTransportFailure(message);
    }
    onTransportReady: {
        recoverRequests();
        if (!isPending("snapshot"))
            refresh();
    }
}
