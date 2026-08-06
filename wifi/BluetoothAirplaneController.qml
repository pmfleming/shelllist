import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import "../bluetooth/BtApi.js" as BtApi

Item {
    id: bridge

    required property WifiController controller
    property var poweredAdapters: []
    property bool enabling: false

    function setAirplaneMode(enabled) {
        enabling = enabled;
        if (enabled)
            client.call("airplane-snapshot", BtApi.methods.snapshot, {});
        else
            restorePoweredAdapters();
    }

    function restorePoweredAdapters() {
        if (poweredAdapters.length === 0)
            return;
        poweredAdapters.forEach(function (key, index) {
            client.call("airplane-restore-" + index, BtApi.methods.setPowered,
                { adapter_key: key, powered: true });
        });
    }

    function handleResponse(id, envelope, transportError) {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            "bt-api", 1, "bt-daemon", "Bluetooth airplane-mode update failed");
        if (error.length > 0) {
            controller.status = error;
            return;
        }
        if (id === "airplane-snapshot") {
            const snapshot = (envelope.data || {}).snapshot || ({});
            poweredAdapters = (snapshot.adapters || []).filter(function (adapter) {
                return !!adapter.powered;
            }).map(function (adapter) { return adapter.key; });
            client.call("airplane-disable-bluetooth", BtApi.methods.setPowered,
                { adapter_key: null, powered: false });
        }
    }

    Io.JsonlDaemonClient {
        id: client
        daemonName: "bt-daemon"
        recoverProtocolErrors: true
        streams: []
        active: bridge.controller.uiActive || bridge.controller.airplaneMode
        onResponse: function (id, envelope, transportError) {
            bridge.handleResponse(id, envelope, transportError);
        }
        onTransportFailed: function (message) {
            bridge.controller.status = "Network radios changed, but Bluetooth could not follow airplane mode: " + message;
        }
    }
}
