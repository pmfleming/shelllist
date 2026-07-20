import QtQuick
import "WifiPresentation.js" as Presentation

Item {
    required property WifiController controller
    required property WifiBackend backend
    required property WifiPromptController prompt
    required property CaptivePortalController portal

    function profileFor(ap) { return controller.profileFor(ap); }
    function capabilities(ap) { return ap && ap.capabilities ? ap.capabilities : ({}); }
    function autoconnectEnabled(ap) { const profile = profileFor(ap); return !!(profile && profile.autoconnect); }
    function randomizedMacEnabled(ap) { return !!Presentation.privacyFor(profileFor(ap)).randomized_mac; }
    function sendHostnameEnabled(ap) { return Presentation.privacyFor(profileFor(ap)).send_hostname !== false; }
    function canProfileAction(ap, capability) { return !controller.actionInFlight && !!profileFor(ap) && capabilities(ap)[capability] === true; }
    function canForget(ap) { return !controller.actionInFlight && (controller.isActive(ap) || capabilities(ap).can_forget === true); }
    function canConnect(ap) { return !controller.isActive(ap) && controller.connection.canBegin(ap); }
    function canDisconnect(ap) { return controller.isActive(ap) && !controller.actionInFlight; }
    function canShare(ap) { return !!ap && !!controller.detailAp && ap.key === controller.detailAp.key && controller.shareController.canShareSelected(); }

    function disconnect(ap) {
        if (!controller.isActive(ap) || !controller.beginAction()) return false;
        controller.status = "Disconnecting Wi-Fi…"; backend.disconnect(); return true;
    }
    function runProfileAction(ap, action) {
        if (!controller.beginAction()) return false;
        const profile = profileFor(ap);
        if (!profile) return false;
        action(profile); return true;
    }
    function forget(ap) {
        if (!canForget(ap)) { controller.status = controller.busyMessage; return false; }
        const profiles = ap.profiles && ap.profiles.length > 0 ? ap.profiles : (profileFor(ap) ? [profileFor(ap)] : []);
        prompt.openForgetPrompt(ap, controller.isActive(ap), profiles); return true;
    }
    function executeForget(ap) {
        if (!controller.beginAction()) return;
        const requestId = "forget-" + Math.round(Date.now());
        controller.status = (controller.isActive(ap) ? "Disconnecting and forgetting " : "Forgetting ") + Presentation.networkName(ap) + "…";
        backend.profile({ operation: "forget", request_id: requestId, key: ap.key });
    }
    function toggleAutoconnect(ap) { return runProfileAction(ap, function (profile) { const enabled = !profile.autoconnect; controller.status = (enabled ? "Enabling" : "Disabling") + " autoconnect for " + profile.id + "…"; backend.profile({ operation: "set-autoconnect", path: profile.path, enabled: enabled }); }); }
    function setMacRandomized(ap, enabled) { return runProfileAction(ap, function (profile) { controller.status = (enabled ? "Using randomized MAC for " : "Using device MAC for ") + profile.id + "…"; backend.profile({ operation: "set-mac-randomization", path: profile.path, randomized: enabled }); }); }
    function toggleSendHostname(ap) { return runProfileAction(ap, function (profile) { const enabled = !(profile.privacy && profile.privacy.send_hostname !== false); controller.status = (enabled ? "Sending" : "Hiding") + " device name for " + profile.id + "…"; backend.profile({ operation: "set-send-hostname", path: profile.path, enabled: enabled }); }); }
    function openPortal(ap) { portal.launchManual(ap, controller.currentWorkspaceId); return true; }
    function execute(actionId, ap) {
        const handlers = {
            connect: function () { return controller.connection.connect(ap); }, "cancel-connect": controller.connection.cancel,
            disconnect: function () { return disconnect(ap); }, forget: function () { return forget(ap); },
            portal: function () { return openPortal(ap); }, share: function () { controller.shareSelected(); return true; },
            autoconnect: function () { return toggleAutoconnect(ap); },
            "randomized-mac": function () { return setMacRandomized(ap, !randomizedMacEnabled(ap)); },
            "send-hostname": function () { return toggleSendHostname(ap); }
        };
        return handlers[actionId] ? handlers[actionId]() !== false : false;
    }
}
