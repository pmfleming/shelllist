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
    function finish(id, envelope, transportError) {
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

    function refresh() { return call("snapshot", BtApi.methods.snapshot, {}); }
    function setPowered(powered) { return call("power", BtApi.methods.setPowered, { powered: powered }); }
    function setScanning(enabled) { return call(enabled ? "scan-start" : "scan-stop", BtApi.methods.scan, { enabled: enabled }); }
    function deviceOperation(operation, device, values) {
        const params = Object.assign({ key: device.key, operation: operation }, values || ({}));
        return call("device-" + operation, BtApi.methods.deviceOperation, params);
    }

    BtDaemonClient {
        id: client
        active: backend.active
        onResponse: function (id, envelope, transportError) { backend.finish(id, envelope, transportError); }
        onTransportFailed: function (message) { backend.controller.status = message; }
    }
}
