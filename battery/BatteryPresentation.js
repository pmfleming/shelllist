.pragma library
.import "../Core/Duration.js" as Duration

// This file is loaded through the Shelllist.Battery module symlink, so resolve
// shared scripts relative to that logical module URL rather than the source tree.
function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, Number(value) || 0));
}

function duration(seconds) {
    return Duration.estimate(seconds, "Estimating");
}

function stateLabel(battery) {
    if (!battery || !battery.available)
        return "Unavailable";
    const labels = {
        "charge-paused": "Charging paused at limit",
        "charging-inhibited": "Charging inhibited",
        "calibrating": "Calibrating battery",
        "fully-charged": "Fully charged",
        "pending-charge": "Waiting to charge",
        "pending-discharge": "Waiting to discharge"
    };
    if (labels[battery.state])
        return labels[battery.state];
    if (battery.charging)
        return "Charging";
    if (battery.plugged && battery.percentage >= 100)
        return "Fully charged";
    if (battery.plugged)
        return "Plugged in";
    return "On battery";
}

function timeLabel(battery) {
    if (!battery || !battery.available)
        return "No estimate";
    if (battery.plugged && !battery.charging)
        return "No active charge estimate";
    const seconds = battery.charging ? battery.time_to_full_seconds : battery.time_to_empty_seconds;
    const suffix = battery.charging ? " until full" : " remaining";
    return duration(seconds) + suffix;
}

function profileName(profile) {
    const labels = {
        "power-saver": "Power saver",
        "balanced": "Balanced",
        "performance": "Performance"
    };
    return labels[profile] || profile || "Unavailable";
}

function automationStatus(automation, available) {
    if (!available)
        return "Automatic switching unavailable · power profile service is offline";
    const value = automation || ({});
    const level = value.level === "critical" ? "Critical battery" : "Low battery";
    return statusMessage({
        paused: "Automatic switching paused · manual profile selected",
        active: level + " · requesting " + profileName(value.profile),
        "keep-current": level + " · keep current profile",
        blocked: "Waiting for another application's profile request to finish",
        unavailable: "Automatic switching unavailable · battery or configured profile is unavailable",
        error: "Automatic switching failed · " + (value.error || "Unknown error"),
        waiting: "Automatic switching ready · waiting for a battery level"
    }, value.status, "Automatic switching status unavailable");
}

// Daemon tokens must not resolve inherited object members such as "constructor".
function statusMessage(messages, status, fallback) {
    return Object.prototype.hasOwnProperty.call(messages, status) ? messages[status] : fallback;
}

function actionName(action) {
    return String(action || "").split("_").map(function (part) {
        return part.length > 0 ? part[0].toUpperCase() + part.slice(1) : part;
    }).join(" ");
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
    if (operation.phase === "discharging")
        return "Calibration: force-discharging to 1%";
    if (operation.phase === "charging")
        return "Calibration: charging fully before restoring thresholds";
    return "Calibration is recovering its saved battery policy";
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
    const inhibited = "Temporarily blocked by an application’s suspend inhibitor";
    return statusMessage({
        yes: "Available · locks before " + transition,
        challenge: "Authorisation required · configure system policy before " + transition,
        inhibited: inhibited,
        "inhibitor-blocked": inhibited,
        "challenge-inhibitor-blocked": "Suspend is inhibited and also requires authorisation",
        no: "Disabled or not permitted by system policy"
    }, capability, "Capability unavailable");
}

function suspendActionName(action) {
    return ({
            lock: "Lock",
            suspend: "Suspend",
            hibernate: "Hibernate"
        })[action] || "Suspend";
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

function protectionRange(protection) {
    if (!protection || !protection.supported)
        return "Unsupported";
    if (protection.start_percent === null || protection.start_percent === undefined || protection.end_percent === null || protection.end_percent === undefined)
        return "Unknown";
    return protection.start_percent + "–" + protection.end_percent + "%";
}

function desiredRange(protection) {
    if (!protection || protection.desired_start_percent === null || protection.desired_start_percent === undefined || protection.desired_end_percent === null || protection.desired_end_percent === undefined)
        return "Not configured";
    return protection.desired_start_percent + "–" + protection.desired_end_percent + "%";
}

function thresholdRangeValid(startPercent, endPercent) {
    const start = Number(startPercent);
    const end = Number(endPercent);
    return Number.isInteger(start) && Number.isInteger(end) && start >= 0 && start < end && end <= 100;
}

function energy(milliwattHours) {
    const value = Math.max(0, Number(milliwattHours) || 0);
    return value >= 1000 ? (value / 1000).toFixed(2) + " Wh" : value.toFixed(value >= 100 ? 0 : 1) + " mWh";
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

function alertRangeValid(warningPercent, criticalPercent) {
    const warning = Number(warningPercent);
    const critical = Number(criticalPercent);
    return Number.isInteger(warning) && Number.isInteger(critical) && critical >= 0 && critical <= warning && warning <= 100;
}

function deviceName(device) {
    if (!device)
        return "System battery";
    const values = [device.vendor || "", device.model || ""].filter(function (value) {
        return value.length > 0;
    });
    return values.length > 0 ? values.join(" ") : (device.id || "System battery");
}
