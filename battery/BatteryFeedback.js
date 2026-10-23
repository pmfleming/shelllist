.pragma library
.import Shelllist.Battery 1.0 as View

// Local pending/error feedback and existing save guards, not unit calculations.
function profileName(profile) {
    return View.BatteryPresentation.lookup(View.BatteryPresentation.profiles, profile || "", {}).label || profile || "Unavailable";
}

function automationStatus(automation, available) {
    if (!available)
        return "Automatic switching unavailable · power profile service is offline";
    const value = automation || ({});
    const level = value.level === "critical" ? "Critical battery" : "Low battery";
    return View.BatteryPresentation.lookup(View.BatteryPresentation.automationMessages, value.status || "", "Automatic switching status unavailable")
        .replace("%1", level).replace("%2", profileName(value.profile)).replace("%3", value.error || "Unknown error");
}

function holdSummary(hold) {
    if (!hold)
        return "";
    const owner = hold.application_id || "An application";
    const reason = hold.reason ? ": " + hold.reason : "";
    return owner + " holds " + profileName(hold.profile) + reason;
}

function calibrationLabel(operation) {
    if (!operation || operation.kind !== "calibration")
        return "";
    return View.BatteryPresentation.lookup(View.BatteryPresentation.calibrationMessages, operation.phase || "", "Calibration is recovering its saved battery policy");
}

function suspendCapabilityAvailable(value) {
    return value === "yes";
}

function suspendInhibitors(state, mode) {
    return ((state || {}).inhibitors || []).filter(function (item) {
        // logind's inhibitor category is an external API token, not a UI label.
        const relevant = String(item.what || "").split(":").indexOf("sleep") >= 0;
        return relevant && (mode === "block" ? ["block", "block-weak"].indexOf(item.mode) >= 0 : item.mode === mode);
    });
}

function suspendCapabilityDescription(state, action) {
    if (!state || !state.available)
        return "Suspend service unavailable";
    if (action === "lock")
        return "Lock the current session";
    const transition = action === "hibernate" ? "hibernating" : "suspending";
    if (state.keep_awake)
        return "Turn off Keep awake before " + transition;
    const capability = action === "suspend" ? state.can_suspend : state.can_hibernate;
    if (capability === "na") {
        const issues = action === "hibernate" ? ((state.diagnostics || {}).hibernate_issues || []) : [];
        return issues.length > 0 ? issues.join(" ") : "Not supported by the system";
    }
    return View.BatteryPresentation.lookup(View.BatteryPresentation.suspendCapabilities, capability || "", "Capability unavailable").replace("%1", transition);
}

function suspendActionName(action) {
    return View.BatteryPresentation.lookup(View.BatteryPresentation.suspendActions, action || "", "Suspend");
}

function suspendStatus(state, pendingAction, retryAction, error) {
    const operation = (state || {}).operation || {};
    const action = suspendActionName(operation.action || pendingAction || retryAction);
    if (state && state.preparing_for_sleep)
        return "Preparing " + action.toLowerCase() + "…";
    if (pendingAction)
        return "Locking…";
    if (operation.phase === "unknown")
        return action + " outcome unknown · inspect the session before another request";
    if (operation.phase === "failed")
        return suspendActionName(operation.action) + " failed";
    if (["requested", "dispatching", "accepted"].includes(operation.phase))
        return action + " requested · awaiting system confirmation";
    if (operation.phase === "returned")
        return "Checking " + action.toLowerCase() + " result…";
    if (error)
        return suspendActionName(retryAction) + " failed";
    if (!state || !state.available)
        return "Suspend controls unavailable";
    if (state.keep_awake)
        return "Keep awake on · suspend & hibernate blocked";
    if (suspendInhibitors(state, "block").length > 0)
        return "Suspend blocked";
    return "";
}

function saveStatus(valid, invalidText, active, error, dirty) {
    if (!valid)
        return invalidText;
    if (active)
        return "Applying automatically…";
    if (error)
        return "Automatic apply failed";
    return dirty ? "Waiting to apply…" : "Applied automatically";
}

function deviceName(device) {
    if (!device)
        return "System battery";
    const values = [device.vendor || "", device.model || ""].filter(function (value) {
        return value.length > 0;
    });
    return values.length > 0 ? values.join(" ") : (device.id || "System battery");
}
