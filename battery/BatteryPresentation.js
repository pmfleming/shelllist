.pragma library

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, Number(value) || 0));
}

function duration(seconds) {
    const value = Math.max(0, Number(seconds) || 0);
    if (value <= 0)
        return "Estimating";
    const hours = Math.floor(value / 3600);
    const minutes = Math.floor((value % 3600) / 60);
    return hours > 0 ? hours + "h " + minutes + "m" : Math.max(1, minutes) + "m";
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
    const seconds = battery.charging
        ? battery.time_to_full_seconds : battery.time_to_empty_seconds;
    const suffix = battery.charging ? " until full" : " remaining";
    return duration(seconds) + suffix;
}

function profileName(profile) {
    const labels = { "power-saver": "Power saver", "balanced": "Balanced",
        "performance": "Performance" };
    return labels[profile] || profile || "Unavailable";
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

function sleepCapabilityAvailable(value) {
    return value === "yes" || value === "challenge";
}

function inhibitorSummary(inhibitor) {
    if (!inhibitor)
        return "";
    const owner = inhibitor.who || "An application";
    const reason = inhibitor.why ? ": " + inhibitor.why : "";
    return owner + " may delay " + (inhibitor.what || "sleep") + reason;
}

function protectionRange(protection) {
    if (!protection || !protection.supported)
        return "Unsupported";
    if (protection.start_percent === null || protection.start_percent === undefined
            || protection.end_percent === null || protection.end_percent === undefined)
        return "Unknown";
    return protection.start_percent + "–" + protection.end_percent + "%";
}

function desiredRange(protection) {
    if (!protection || protection.desired_start_percent === null
            || protection.desired_start_percent === undefined
            || protection.desired_end_percent === null
            || protection.desired_end_percent === undefined)
        return "Not configured";
    return protection.desired_start_percent + "–" + protection.desired_end_percent + "%";
}

function thresholdRangeValid(startPercent, endPercent) {
    const start = Number(startPercent);
    const end = Number(endPercent);
    return Number.isInteger(start) && Number.isInteger(end)
        && start >= 0 && start < end && end <= 100;
}

function energy(milliwattHours) {
    const value = Math.max(0, Number(milliwattHours) || 0);
    return value >= 1000 ? (value / 1000).toFixed(2) + " Wh"
        : value.toFixed(value >= 100 ? 0 : 1) + " mWh";
}

function historyRange(history) {
    const points = history && history.points ? history.points : [];
    if (points.length === 0)
        return "Collecting samples";
    const first = new Date(Number(points[0].timestamp_ms || 0));
    const last = new Date(Number(points[points.length - 1].timestamp_ms || 0));
    return first.toLocaleDateString() + " – " + last.toLocaleDateString();
}

function alertRangeValid(warningPercent, criticalPercent) {
    const warning = Number(warningPercent);
    const critical = Number(criticalPercent);
    return Number.isInteger(warning) && Number.isInteger(critical)
        && critical >= 0 && critical <= warning && warning <= 100;
}

function deviceName(device) {
    if (!device)
        return "System battery";
    const values = [device.vendor || "", device.model || ""]
        .filter(function (value) { return value.length > 0; });
    return values.length > 0 ? values.join(" ") : (device.id || "System battery");
}
