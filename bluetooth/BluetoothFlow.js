.pragma library

function pairingTransition(currentPrompt, envelope) {
    const event = envelope || ({});
    const prompt = event.data || ({});
    if (["requested", "display"].includes(event.event))
        return { changed: true, prompt: prompt };
    const matchingCancellation = event.event === "cancelled"
        && currentPrompt && currentPrompt.request_id === prompt.request_id;
    return matchingCancellation
        ? { changed: true, prompt: null }
        : { changed: false, prompt: currentPrompt || null };
}

function isActiveOperation(operation) {
    return !!operation && ["queued", "running"].includes(operation.state);
}

function isTerminalOperation(operation) {
    return !!operation && ["completed", "failed", "cancelled"].includes(operation.state);
}

function operationEndsPairing(operation, prompt) {
    return isTerminalOperation(operation) && !!prompt && prompt.device_key === operation.device_key;
}

function isTerminalTransfer(transfer) {
    return !!transfer && ["complete", "cancelled", "error"].includes(transfer.status);
}

function retainedAdapterKey(adapters, currentKey) {
    const retained = adapters.some(function (adapter) { return adapter.key === currentKey; });
    return retained || adapters.length === 0 ? currentKey : adapters[0].key;
}

function shouldStartScan(uiActive, powered, scanning, requested) {
    return uiActive && powered && !scanning && !requested;
}

function snapshotStatus(powered, scanning, count) {
    if (!powered) return "Bluetooth is off";
    return scanning ? count + " devices · scanning…" : count + " Bluetooth devices";
}

function deviceState(device) {
    if (device.connected) return "Connected";
    if (device.paired) return "Paired";
    return device.present ? "Available" : "Not in range";
}

function deviceScore(device) {
    return (device.connected ? 10000 : 0)
        + (device.paired ? 1000 : 0)
        + (device.signal_strength || 0);
}
