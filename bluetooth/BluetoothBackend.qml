import QtQuick
import "BtApi.js" as BtApi

Item {
    id: backend

    required property var controller
    property var pending: ({})
    property var operations: ({})
    property var finishedOperations: ({})
    readonly property bool active: controller.uiActive || Object.keys(pending).length > 0 || Object.keys(operations).length > 0
    readonly property bool running: Object.keys(pending).length > 0 || Object.keys(operations).length > 0

    function isPending(id) { return !!pending[id]; }
    function call(id, method, params) {
        if (isPending(id))
            return false;
        pending[id] = true;
        pending = Object.assign({}, pending);
        client.call(id, method, params);
        return true;
    }
    function isSessionControl(id) { return id === "session-subscribe" || id.indexOf("cancel-subscription-") === 0 || id.indexOf("shutdown-") === 0; }
    function finish(id, envelope, transportError) {
        if (isSessionControl(id))
            return;
        delete pending[id];
        pending = Object.assign({}, pending);
        if (transportError.length > 0) {
            controller.status = transportError;
            return;
        }
        if (!envelope || envelope.protocol !== "bt-api" || envelope.version !== 1) {
            controller.status = "bt-daemon returned an incompatible response";
            return;
        }
        if (!envelope.ok) {
            controller.status = (envelope.error && envelope.error.message) || "Bluetooth operation failed";
            return;
        }
        if (id.indexOf("cancel-operation-") === 0) {
            controller.status = "Cancelling Bluetooth operation…";
            return;
        }
        const audioDevices = envelope.data ? envelope.data.audio_devices : null;
        if (audioDevices) {
            controller.applyAudioSnapshot(audioDevices);
            if (id === "audio-set-profile")
                controller.status = "Bluetooth audio profile updated";
            return;
        }
        const operation = envelope.data ? envelope.data.operation : null;
        if (operation) {
            if (finishedOperations[operation.request_id]) {
                delete finishedOperations[operation.request_id];
                finishedOperations = Object.assign({}, finishedOperations);
                return;
            }
            operations[operation.request_id] = operation;
            operations = Object.assign({}, operations);
            controller.handleOperationAccepted(operation);
            return;
        }
        const snapshot = envelope.data ? envelope.data.snapshot : null;
        if (snapshot)
            controller.applySnapshot(snapshot);
        if (id !== "snapshot")
            controller.status = controller.statusForCompletedCall(id);
    }

    function handleEvent(event) {
        if (!event || event.protocol !== "bt-api" || event.version !== 1)
            return;
        if (event.stream === BtApi.streams.pairing) {
            controller.handlePairingEvent(event);
            return;
        }
        if (event.stream === BtApi.streams.operation) {
            const operation = event.data || ({});
            if (operation.request_id) {
                if (operation.state === "completed" || operation.state === "failed" || operation.state === "cancelled") {
                    if (!operations[operation.request_id]) {
                        finishedOperations[operation.request_id] = true;
                        finishedOperations = Object.assign({}, finishedOperations);
                    }
                    delete operations[operation.request_id];
                } else
                    operations[operation.request_id] = operation;
                operations = Object.assign({}, operations);
            }
            controller.handleOperationEvent(operation);
            return;
        }
        if (event.event === "unavailable") {
            controller.status = (event.error && event.error.message) || "BlueZ is unavailable";
            return;
        }
        const snapshot = event.data ? event.data.snapshot : null;
        if (snapshot)
            controller.applySnapshot(snapshot);
    }

    function refresh() { return call("snapshot", BtApi.methods.snapshot, {}); }
    function refreshAudio() { return call("audio-snapshot", BtApi.methods.audioSnapshot, {}); }
    function setAudioProfile(deviceKey, profileKey) { return call("audio-set-profile", BtApi.methods.audioSetProfile, { device_key: deviceKey, profile_key: profileKey }); }
    function setPowered(powered) { return call("power", BtApi.methods.setPowered, { powered: powered }); }
    function setScanning(enabled) { return call(enabled ? "scan-start" : "scan-stop", BtApi.methods.scan, { enabled: enabled }); }
    function cancelOperation(requestId) {
        if (!requestId || !operations[requestId])
            return false;
        client.cancel("cancel-operation-" + requestId, requestId);
        return true;
    }
    function respondPairing(requestId, accept, value) {
        const params = { request_id: requestId, accept: !!accept };
        if (value !== undefined && value !== null)
            params.value = value;
        return call("pairing-response", BtApi.methods.pairingRespond, params);
    }
    function deviceOperation(operation, device, values) {
        const params = Object.assign({ key: device.key, operation: operation }, values || ({}));
        return call("device-" + operation, BtApi.methods.deviceOperation, params);
    }

    BtDaemonClient {
        id: client
        active: backend.active
        onResponse: function (id, envelope, transportError) { backend.finish(id, envelope, transportError); }
        onEventReceived: function (event) { backend.handleEvent(event); }
        onTransportFailed: function (message) {
            backend.operations = ({});
            backend.finishedOperations = ({});
            backend.controller.handleTransportFailure(message);
        }
    }
}
