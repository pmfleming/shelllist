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
    if (event.stream === streams.battery)
        return "battery";
    if (event.stream === streams.powerProfile)
        return "powerProfile";
    if (event.stream === streams.powerSleep)
        return "powerSleep";
    return "";
}
