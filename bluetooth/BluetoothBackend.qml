import QtQuick
import Shelllist.Io as Io
import "BtApi.js" as BtApi

Io.DaemonBackend {
    id: backend

    required property BluetoothController controller
    property var operations: ({})
    property var finishedOperations: ({})
    property string nameRequestKey: ""
    property var pendingAudioProfile: null
    property var adapterRequestKeys: ({})

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
                backend.acceptScan(data.scan, data.snapshot);
            },
            audio_devices: function (id, data) {
                backend.controller.applyAudioSnapshot(data.audio_devices);
                if (id === "audio-set-profile")
                    backend.controller.status = "Bluetooth audio profile updated";
                else if (id === "audio-set-default")
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
        pendingAudioProfile = null;
        nameRequestKey = "";
        adapterRequestKeys = ({});
        pending = ({});
        operations = ({});
        finishedOperations = ({});
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
    function finishDeviceRequest(id: string, error: string): void {
        if (id === "device-set-alias") {
            if (error)
                controller.nameEdits.rejected(nameRequestKey, error);
            nameRequestKey = "";
        }
        if (id === "pairing-response")
            controller.finishPairingResponse(error.length === 0);
    }
    function rememberAudioProfile(id: string, audioProfile: var): void {
        if (audioProfile) {
            controller.status = "Remembering Bluetooth audio profile…";
            if (!call("audio-profile-policy", BtApi.methods.devicePolicyUpdate, {
                key: audioProfile.deviceKey, preferred_audio_profile_key: audioProfile.profileKey
            }))
                controller.status = "Audio profile applied, but could not remember it";
        } else if (id === "audio-profile-policy") {
            controller.status = "Bluetooth audio profile updated and remembered";
        }
    }
    function finish(id: string, envelope: var, transportError: string): void {
        const error = responseError(envelope, transportError, "Bluetooth operation failed");
        const audioProfile = id === "audio-set-profile" ? pendingAudioProfile : null;
        if (id === "audio-set-profile")
            pendingAudioProfile = null;
        finishDeviceRequest(id, error);
        if (error.length > 0) {
            finishAdapterRequest(id, error);
            console.error("shelllist bluetooth request failed id=" + id + " stage=response error=" + error);
            controller.status = id === "audio-profile-policy"
                ? "Audio profile applied, but could not remember it: " + error : error;
            return;
        }
        if (id.startsWith("cancel-operation-")) {
            console.info("shelllist bluetooth cancellation accepted id=" + id);
            controller.status = "Cancelling Bluetooth operation…";
            return;
        }
        try {
            applyResponse(id, envelope.data || ({}));
            rememberAudioProfile(id, audioProfile);
            finishAdapterRequest(id, "");
            console.info("shelllist bluetooth request completed id=" + id);
        } catch (applyError) {
            finishAdapterRequest(id, "Could not read the saved adapter settings: " + applyError);
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

    function applyUnhandledEvent(event) {
        if (event.event === "unavailable" || event.event === "loading") {
            controller.invalidateBluetooth((event.error && event.error.message) || (event.event === "loading" ? "Bluetooth is loading…" : "BlueZ is unavailable"));
            return;
        }
        if (event.data && event.data.snapshot) {
            controller.applySnapshot(event.data.snapshot);
            return;
        }
        console.warn("shelllist bluetooth event ignored stream=" + (event.stream || "unknown") + " event=" + (event.event || "unknown"));
    }
    function recoverEventGap(): void {
        controller.status = "Bluetooth events were missed; recovering current state…";
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
        if (event.event === "unavailable")
            controller.invalidateAudio((event.error && event.error.message) || "Bluetooth audio is unavailable");
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

    function refresh() {
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
        const accepted = cancel(requestId, "cancel-" + kind + "-" + requestId);
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
        if (isPending("audio-set-profile") || isPending("audio-profile-policy"))
            return false;
        // Capture the device now: selection can change before the reply arrives.
        pendingAudioProfile = {deviceKey: deviceKey, profileKey: profileKey};
        const sent = call("audio-set-profile", BtApi.methods.audioSetProfile, {
            device_key: deviceKey,
            profile_key: profileKey
        });
        if (!sent)
            pendingAudioProfile = null;
        return sent;
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
            const accepted = cancel(requestId, "cancel-scan-" + requestId);
            if (accepted)
                console.info("shelllist bluetooth scan cancellation requested request_id=" + requestId);
            return accepted;
        }
        return call("scan-start", BtApi.methods.scan, {
            enabled: true,
            adapter_key: adapterKey || null,
            timeout_ms: 15000
        });
    }
    function finishAdapterRequest(id, error) {
        const key = adapterRequestKeys[id];
        if (!key)
            return;
        adapterRequestKeys = BtApi.copyWithout(adapterRequestKeys, id);
        controller.adapterEdits.finish(key, id.slice("adapter-".length), error);
    }
    function adapterOperation(operation, adapter, values) {
        const id = "adapter-" + operation;
        if (isPending(id))
            return false;
        adapterRequestKeys = BtApi.copyWith(adapterRequestKeys, id, adapter.key);
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
    onEventGapDetected: recoverEventGap()
    onEventReceived: function (event) {
        handleEvent(event);
    }
    onSendFailed: function (id, message) {
        controller.status = message;
    }
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
