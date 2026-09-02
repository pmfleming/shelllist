.pragma library
.import "BtProtocol.generated.js" as Protocol

var streams = {
    changed: Protocol.streams["bluetooth.changed"],
    pairing: Protocol.streams["pairing.request"],
    audio: Protocol.streams["bluetooth.audio.changed"],
    operation: Protocol.streams["bluetooth.operation"],
    scan: Protocol.streams["bluetooth.scan"]
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
    protocolDescribe: Protocol.methods["bluetooth.protocol.describe"],
    snapshot: Protocol.methods["bluetooth.snapshot"],
    setPowered: Protocol.methods["bluetooth.setPowered"],
    scan: Protocol.methods["bluetooth.scan"],
    adapterOperation: Protocol.methods["bluetooth.adapter.operation"],
    managementUpdate: Protocol.methods["bluetooth.management.update"],
    audioSetProfile: Protocol.methods["bluetooth.audio.setProfile"],
    requestsSnapshot: Protocol.methods["bluetooth.requests.snapshot"],
    pairingRespond: Protocol.methods["bluetooth.pairing.respond"],
    deviceOperation: Protocol.methods["bluetooth.device.operation"]
};
