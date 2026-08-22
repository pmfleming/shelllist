import QtQuick
import "NmApiClient.js" as Api

// Saved VPN and WireGuard profiles. Activation is event-driven so a plugin's
// own failure reason reaches the user instead of a generic "could not connect".
Item {
    id: vpn

    required property WifiController controller
    required property WifiBackend backend

    property var profiles: []
    property var active: []
    property string requestId: ""
    property string connectingUuid: ""

    readonly property bool connecting: requestId.length > 0
    readonly property bool busy: connecting || backend.isPending("vpn-connect")
        || backend.isPending("vpn-disconnect")

    function refresh() {
        backend.loadVpnProfiles();
        backend.loadVpnStatus();
    }

    function activeFor(uuid) {
        for (let index = 0; index < active.length; index++) {
            if (active[index].uuid === uuid)
                return active[index];
        }
        return null;
    }

    function isActive(uuid) { return !!activeFor(uuid); }

    function connect(profile) {
        if (!profile || !profile.uuid) {
            controller.status = "Could not start the VPN: no profile selected.";
            return false;
        }
        if (connecting) {
            controller.status = "A VPN connection is already starting.";
            return false;
        }
        connectingUuid = profile.uuid;
        return backend.connectVpn({ uuid: profile.uuid });
    }

    function disconnect(profile) {
        const uuid = profile && profile.uuid ? profile.uuid : "";
        return backend.disconnectVpn(uuid.length > 0 ? { uuid: uuid } : ({}));
    }

    function cancel() {
        if (requestId.length === 0)
            return false;
        const cancelled = backend.cancel(requestId);
        if (!cancelled)
            console.warn("shelllist vpn cancellation failed request_id=" + requestId);
        return cancelled;
    }

    function applyProfiles(value) { profiles = value || []; }
    function applyStatus(value) { active = (value && value.active) || []; }
    function applyConnectStart(result) {
        requestId = (result && result.request_id) || "";
        controller.status = (result && result.message) || "Connecting to the VPN…";
    }
    function applyDisconnect(result) {
        controller.status = (result && result.message) || "VPN disconnected";
        refresh();
    }

    function handleEvent(event) {
        if (!Api.requestMatches(event, requestId))
            return;
        if (event.event === "progress") {
            controller.status = "Connecting to the VPN…";
            return;
        }
        if (event.event !== "succeeded" && !Api.isTerminalEvent(event))
            return;
        requestId = "";
        connectingUuid = "";
        controller.status = event.event === "succeeded"
            ? ((event.result && event.result.message) || "VPN connected")
            : failureMessage(event);
        refresh();
    }

    // The daemon reports the plugin's own reason; prefer it over the generic
    // activation message so "needs a password" does not read as "failed".
    function failureMessage(event) {
        if (event.event === "cancelled")
            return event.message || "VPN connection cancelled";
        const details = event.details || ({});
        if (details.reason === "no-secrets")
            return "The VPN needs credentials.";
        if (details.reason === "login-failed")
            return "The VPN rejected the sign-in.";
        return event.message || "The VPN could not connect.";
    }
}
