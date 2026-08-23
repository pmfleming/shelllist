import QtQuick
import "NmApi.js" as NmApi

// Cross-type NetworkManager inventory: wired, VPN, WireGuard, cellular, and
// virtual connections alongside Wi-Fi.
//
// network.inventory is not a default subscription. The daemon only computes the
// payload while somebody is watching, so the subscription is taken when this
// view opens and dropped when it closes.
Item {
    required property WifiController controller
    required property WifiBackend backend

    property bool watching: false
    property string subscriptionRequestId: ""
    property var devices: []
    property var connections: []
    property var activeConnections: []
    property var networkState: null

    readonly property bool busy: backend.isPending("inventory") || backend.isPending("network-status")

    function open() {
        if (watching)
            return;
        watching = true;
        subscriptionRequestId = backend.subscribeStreams([NmApi.streams.network_inventory]);
        refresh();
    }

    function close() {
        if (!watching)
            return;
        watching = false;
        if (subscriptionRequestId.length > 0 && !backend.unsubscribeStreams(subscriptionRequestId))
            console.warn("shelllist inventory unsubscribe failed id=" + subscriptionRequestId);
        subscriptionRequestId = "";
    }

    function refresh() {
        backend.loadInventory();
        backend.loadNetworkState();
    }

    function devicesOfType(typeName) {
        return devices.filter(function (device) { return device.type_name === typeName; });
    }

    function connectionsOfType(typeName) {
        return connections.filter(function (profile) { return profile.type_name === typeName; });
    }

    function activate(profile, device) {
        if (!profile || (!profile.uuid && !profile.path)) {
            controller.status = "Could not activate the connection: no profile selected.";
            return false;
        }
        const request = profile.uuid ? { uuid: profile.uuid } : { path: profile.path };
        if (device)
            request.device = device;
        return backend.activateProfile(request);
    }

    function deactivate(activeConnection) {
        if (!activeConnection || !activeConnection.path) {
            controller.status = "Could not deactivate the connection: nothing is active.";
            return false;
        }
        return backend.deactivateConnection({ path: activeConnection.path });
    }

    function applyInventory(value) {
        const snapshot = value || ({});
        devices = snapshot.devices || [];
        connections = snapshot.connections || [];
        activeConnections = snapshot.active_connections || [];
    }
    function applyNetworkState(value) { networkState = value || null; }
    function applyActivation(result) {
        controller.status = (result && result.message) || "Activating the connection…";
        refresh();
    }
    function applyDeactivation(result) {
        controller.status = (result && result.message) || "Connection deactivated";
        refresh();
    }

    function handleEvent(event) {
        if (event.event !== "changed")
            return;
        applyInventory(event.inventory || null);
    }
}
