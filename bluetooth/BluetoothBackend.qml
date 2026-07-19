import QtQuick
import "BtApi.js" as BtApi

Item {
    id: backend

    required property var controller
    property var pending: ({})
    readonly property bool active: controller.uiActive || Object.keys(pending).length > 0
    readonly property bool running: Object.keys(pending).length > 0

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
        if (event.event === "unavailable") {
            controller.status = (event.error && event.error.message) || "BlueZ is unavailable";
            return;
        }
        const snapshot = event.data ? event.data.snapshot : null;
        if (snapshot)
            controller.applySnapshot(snapshot);
    }

    function refresh() { return call("snapshot", BtApi.methods.snapshot, {}); }
    function setPowered(powered) { return call("power", BtApi.methods.setPowered, { powered: powered }); }
    function setScanning(enabled) { return call(enabled ? "scan-start" : "scan-stop", BtApi.methods.scan, { enabled: enabled }); }
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
        onTransportFailed: function (message) { backend.controller.status = message; }
    }
}
