.pragma library

function selection(state, requestedIndex, requestedId) {
    const battery = state || ({});
    const devices = Array.isArray(battery.devices) ? battery.devices : [];
    const matchingIndex = requestedId ? devices.findIndex(function (device) {
        return device.id === requestedId;
    }) : requestedIndex;
    const index = matchingIndex >= 0 && matchingIndex < devices.length ? matchingIndex : 0;
    const device = devices.length > index ? devices[index] : null;
    return {
        index: index,
        device: device,
        policy: battery.policy || ({}),
        protection: device && device.protection ? device.protection : (battery.protection || ({}))
    };
}

function operationActive(state) {
    const battery = state || ({});
    return !!(battery.operation && battery.operation.kind) || !!(battery.protection && battery.protection.charge_once_active) || (battery.devices || []).some(function (device) {
        return !!(device.protection && device.protection.charge_once_active);
    });
}

function historyChanges(nextBattery, currentHistory) {
    const summary = (nextBattery || ({})).history || ({});
    const current = currentHistory || ({});
    const latest = Number(summary.latest_timestamp_ms || 0);
    const charge = Number(summary.last_charge_timestamp_ms || 0);
    return {
        history: latest > 0 && latest !== Number(current.latest_timestamp_ms || 0),
        charge: charge > 0 && charge !== Number(current.last_charge_timestamp_ms || 0)
    };
}

function energyRequest(period, forceRefresh, now, updated, lastCharge) {
    if (!forceRefresh && now - updated < 60000)
        return null;
    const weekSince = now - 7 * 24 * 60 * 60 * 1000;
    return {
        period: period,
        since: period === "week" || lastCharge <= 0 ? weekSince : lastCharge
    };
}

function eventKind(event, streams) {
    if (event.event === "lagged")
        return "lagged";
    if (!["subscribed", "changed"].includes(event.event))
        return "";
    return ["battery", "powerProfile", "powerSuspend", "suspendPolicy"].find(function (kind) {
        return event.stream === streams[kind];
    }) || "";
}

function valueOr(value, fallback) {
    return value === null || value === undefined ? fallback : value;
}

// Alert policy fields per battery level, in the daemon's setAlertPolicy names.
var levelFields = ({
        low: {
            percent: "warning_percent",
            notify: "notify_warning",
            profile: "warning_profile"
        },
        critical: {
            percent: "critical_percent",
            notify: "notify_critical",
            profile: "critical_profile"
        }
    });

// The editable alert policy, which is also the setAlertPolicy payload.
function alertDraft(policy) {
    const current = policy || ({});
    const legacyProfile = valueOr(current.auto_power_saver, true) ? "power-saver" : "keep-current";
    return {
        warning_percent: Number(valueOr(current.warning_percent, 25)),
        critical_percent: Number(valueOr(current.critical_percent, 12)),
        notify_when_full: valueOr(current.notify_when_full, true),
        notify_warning: valueOr(current.notify_warning, true),
        notify_critical: valueOr(current.notify_critical, true),
        warning_profile: valueOr(current.warning_profile, legacyProfile),
        critical_profile: valueOr(current.critical_profile, legacyProfile)
    };
}

function validSuspendPolicyValue(profile, field, value) {
    if (profile === "critical_battery") {
        if (field === "enabled")
            return typeof value === "boolean";
        const range = {
            percent: [1, 20],
            grace_seconds: [30, 300]
        }[field];
        return !!range && Number.isInteger(value) && value >= range[0] && value <= range[1];
    }
    if (field === "same_profile")
        return typeof value === "boolean";
    if (field === "lid_action")
        return ["system", "ignore", "lock", "suspend", "hibernate", "profile"].includes(value);
    return ["battery", "plugged"].includes(profile) && ["sleep_minutes", "hibernate_minutes"].includes(field) && Number.isInteger(value) && value >= 0 && value <= 10080;
}

// The suspend policy with one field changed, or null when the change is invalid.
function editSuspendPolicy(draft, profile, field, value) {
    if (!validSuspendPolicyValue(profile, field, value))
        return null;
    const next = JSON.parse(JSON.stringify(draft));
    if (profile === "critical_battery") {
        next.critical_battery = Object.assign({
            enabled: false,
            percent: 5,
            grace_seconds: 60
        }, next.critical_battery || {});
        next.critical_battery[field] = value;
    } else if (field === "same_profile" || field === "lid_action") {
        next[field] = value;
    } else {
        next[profile][field] = value;
    }
    return next;
}
