.pragma library
.import "BtProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;

// File transfer (OBEX) is implemented in bt-daemon, NOT in Shelllist.
// This frontend has no send/receive approval, progress, or cancellation UI.
// Do not subscribe to or advertise OBEX until that complete workflow exists;
// use Blueman for transfers. bt-daemon's incoming agent is opt-in for other clients.
var streams = {
    changed: Protocol.streams["bluetooth.changed"],
    pairing: Protocol.streams["pairing.request"],
    audio: Protocol.streams["bluetooth.audio.changed"],
    operation: Protocol.streams["bluetooth.operation"],
    scan: Protocol.streams["bluetooth.scan"]
};

var subscribedStreams = Object.keys(streams).map(function (name) {
    return streams[name];
});

// Wire shape only. Ordering and synchronous publication remain in the backend.
function objectValue(value) {
    return !!value && typeof value === "object" && !Array.isArray(value);
}
function keyedItems(items) {
    return Array.isArray(items) && items.every(item => objectValue(item)
        && typeof item.key === "string" && !!item.key);
}
function validSnapshot(data, audio) {
    if (audio)
        return Array.isArray(data.audio_devices) && data.audio_devices.every(device =>
            objectValue(device) && typeof device.device_key === "string" && !!device.device_key
            && Array.isArray(device.profiles));
    const snapshot = data.snapshot;
    return objectValue(snapshot) && objectValue(snapshot.radio) && objectValue(snapshot.management)
        && typeof snapshot.radio.available === "boolean" && typeof snapshot.radio.operational === "boolean"
        && typeof snapshot.radio.powered === "boolean" && keyedItems(snapshot.adapters) && keyedItems(snapshot.devices);
}

function activeOperation(operation) {
    return operation.state === "queued" || operation.state === "running";
}
function validOperation(operation) {
    return objectValue(operation) && typeof operation.request_id === "string" && !!operation.request_id
        && Number.isSafeInteger(operation.revision) && operation.revision > 0
        && typeof operation.device_key === "string" && !!operation.device_key
        && typeof operation.operation === "string" && !!operation.operation
        && typeof operation.stage === "string" && !!operation.stage
        && ["queued", "running", "completed", "failed", "cancelled"].includes(operation.state);
}

var responseKeys = ["scan", "audio_devices", "operation", "requests"];

function responseKind(data) {
    return responseKeys.find(function (key) {
        return !!data[key];
    }) || "";
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

var methods = {
    snapshot: Protocol.methods["bluetooth.snapshot"],
    setPowered: Protocol.methods["bluetooth.setPowered"],
    scan: Protocol.methods["bluetooth.scan"],
    adapterOperation: Protocol.methods["bluetooth.adapter.operation"],
    adapterUpdate: Protocol.methods["bluetooth.adapter.update"],
    managementUpdate: Protocol.methods["bluetooth.management.update"],
    devicePolicyUpdate: Protocol.methods["bluetooth.device.policy.update"],
    audioSetDefault: Protocol.methods["bluetooth.audio.setDefault"],
    audioSnapshot: Protocol.methods["bluetooth.audio.snapshot"],
    audioSetProfile: Protocol.methods["bluetooth.audio.setProfile"],
    requestsSnapshot: Protocol.methods["bluetooth.requests.snapshot"],
    operationStatus: Protocol.methods["bluetooth.operation.status"],
    pairingRespond: Protocol.methods["bluetooth.pairing.respond"],
    deviceOperation: Protocol.methods["bluetooth.device.operation"]
};
