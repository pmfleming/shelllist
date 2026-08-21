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
    const seconds = battery.charging
        ? battery.time_to_full_seconds : battery.time_to_empty_seconds;
    const suffix = battery.charging ? " until full" : " remaining";
    return duration(seconds) + suffix;
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
