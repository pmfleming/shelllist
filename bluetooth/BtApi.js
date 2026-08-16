.pragma library

var streams = {
    changed: "bluetooth.changed",
    pairing: "pairing.request",
    audio: "bluetooth.audio.changed",
    operation: "bluetooth.operation",
    scan: "bluetooth.scan"
};

var responseKeys = ["scan", "audio_devices", "operation", "requests"];

function responseKind(data) {
    return responseKeys.find(function (key) { return !!data[key]; }) || "";
}

function copyWithout(values, key) {
    const result = Object.assign({}, values);
    delete result[key];
    return result;
}

function copyWith(values, key, value) {
    const result = Object.assign({}, values);
    result[key] = value;
    return result;
}

function lifecycleState(item, activeItems, finishedItems, state, terminalStates) {
    const id = item.request_id;
    if (!id)
        return { active: activeItems, finished: finishedItems };
    if (!terminalStates.includes(state))
        return { active: copyWith(activeItems, id, item), finished: finishedItems };
    return {
        active: copyWithout(activeItems, id),
        finished: activeItems[id] ? finishedItems : copyWith(finishedItems, id, true)
    };
}

var methods = {
    protocolDescribe: "bluetooth.protocol.describe",
    snapshot: "bluetooth.snapshot",
    setPowered: "bluetooth.setPowered",
    scan: "bluetooth.scan",
    adapterOperation: "bluetooth.adapter.operation",
    managementUpdate: "bluetooth.management.update",
    devicePolicyUpdate: "bluetooth.device.policy.update",
    audioSetProfile: "bluetooth.audio.setProfile",
    audioSetDefault: "bluetooth.audio.setDefault",
    requestsSnapshot: "bluetooth.requests.snapshot",
    pairingRespond: "bluetooth.pairing.respond",
    deviceOperation: "bluetooth.device.operation"
};
