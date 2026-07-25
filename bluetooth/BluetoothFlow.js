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

function operationDeviceName(results, deviceKey) {
    const result = (results || []).find(function (candidate) { return candidate.id === deviceKey; });
    return result ? result.title : "Bluetooth device";
}

function withoutMatchingOperation(current, requestId) {
    return current && current.request_id === requestId ? null : current;
}

function shouldRescanAfterOperation(operation, uiActive, powered, scanning) {
    return !!operation && operation.operation === "pair" && operation.state === "failed"
        && !!operation.error && operation.error.code === "device-unavailable"
        && uiActive && powered && !scanning;
}

function isTerminalTransfer(transfer) {
    return !!transfer && ["complete", "cancelled", "error"].includes(transfer.status);
}

function matchingRequest(current, update) {
    return !!current && current.request_id === update.request_id;
}

function transferTransition(activeTransfer, prompt, transfer) {
    if (!transfer || !transfer.request_id)
        return null;
    if (transfer.status === "awaiting-authorization")
        return { activeTransfer: transfer, prompt: transfer,
            status: "Incoming file transfer approval required", authorizationRequested: true };
    const nextPrompt = matchingRequest(prompt, transfer) ? null : prompt;
    if (isTerminalTransfer(transfer))
        return { activeTransfer: matchingRequest(activeTransfer, transfer) ? null : activeTransfer,
            prompt: nextPrompt, status: transferCompletionStatus(transfer), authorizationRequested: false };
    return { activeTransfer: transfer, prompt: nextPrompt,
        status: transferProgressStatus(transfer), authorizationRequested: false };
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

function completedCallStatus(id, powered, currentStatus) {
    const messages = ({
        power: powered ? "Bluetooth turned on" : "Bluetooth turned off",
        "scan-start": "Scanning for Bluetooth devices…",
        "scan-stop": "Bluetooth scan stopped",
        "pairing-response": "Pairing response sent"
    });
    if (messages[id]) return messages[id];
    if (id.indexOf("cancel-scan-") === 0) return messages["scan-stop"];
    return id.indexOf("device-") === 0 ? "Bluetooth device updated" : currentStatus;
}

function scanCompletionStatus(scan, deviceCount, currentStatus) {
    const messages = ({
        completed: deviceCount + " Bluetooth devices · scan complete",
        cancelled: "Bluetooth scan stopped",
        failed: (scan.error && scan.error.message) || "Bluetooth scan failed"
    });
    return messages[scan.state] || currentStatus;
}

function transferCompletionStatus(transfer) {
    if (transfer.status === "complete")
        return transfer.direction === "incoming" ? transfer.file_name + " saved in Downloads" : transfer.file_name + " sent";
    if (transfer.status === "cancelled") return "File transfer cancelled";
    return (transfer.error && transfer.error.message) || "File transfer failed";
}

function transferProgressStatus(transfer) {
    const percentage = transfer.size > 0 ? Math.floor(transfer.transferred * 100 / transfer.size) : 0;
    const verb = transfer.direction === "incoming" ? "Receiving " : "Sending ";
    return verb + transfer.file_name + (transfer.size > 0 ? " · " + percentage + "%" : "…");
}

function operationCompletionStatus(operation, deviceName) {
    if (operation.state === "completed") return deviceName + " updated";
    if (operation.state === "cancelled") return "Bluetooth operation cancelled";
    return (operation.error && operation.error.message) || "Bluetooth operation failed";
}

function activeOperationStatus(operation, deviceName) {
    return operation.operation.charAt(0).toUpperCase() + operation.operation.slice(1) + " " + deviceName + "…";
}

function operationTransition(activeOperation, pairingPrompt, operation, deviceName, uiActive, powered, scanning) {
    if (!operation || !operation.request_id)
        return null;
    if (isActiveOperation(operation))
        return { activeOperation: operation, active: true, clearPairing: false,
            status: activeOperationStatus(operation, deviceName), rescan: false };
    const rescan = shouldRescanAfterOperation(operation, uiActive, powered, scanning);
    return {
        activeOperation: withoutMatchingOperation(activeOperation, operation.request_id),
        active: false,
        clearPairing: operationEndsPairing(operation, pairingPrompt),
        status: rescan ? "Device is no longer nearby · scanning again…" : operationCompletionStatus(operation, deviceName),
        rescan: rescan
    };
}

const directOperations = ({ pair: "pair", connect: "connect", disconnect: "disconnect", forget: "remove" });
const toggleOperations = ({
    trusted: { operation: "set-trusted", field: "trusted" },
    wake: { operation: "set-wake-allowed", field: "wake_allowed" },
    blocked: { operation: "set-blocked", field: "blocked" }
});

function directActionRequest(actionId, device, trustAfterPair) {
    const operation = directOperations[actionId];
    if (!operation)
        return null;
    const verb = actionId === "forget" ? "Forgetting" : operation.charAt(0).toUpperCase() + operation.slice(1);
    return { operation: operation,
        values: operation === "pair" ? { trust_after_pair: trustAfterPair } : ({}),
        status: verb + " " + device.name + "…" };
}

function toggleActionRequest(actionId, device) {
    const toggle = toggleOperations[actionId];
    if (!toggle)
        return null;
    const values = ({});
    values[toggle.field] = !device[toggle.field];
    return { operation: toggle.operation, values: values, status: "" };
}

function multipointActionRequest(device) {
    const multipoint = (device.fast_pair && device.fast_pair.multipoint) || ({});
    return { operation: "set-multipoint", values: { enabled: !multipoint.enabled },
        status: (multipoint.enabled ? "Disabling" : "Enabling") + " multipoint for " + device.name + "…" };
}

function deviceActionRequest(actionId, device, trustAfterPair) {
    return directActionRequest(actionId, device, trustAfterPair)
        || toggleActionRequest(actionId, device)
        || (actionId === "multipoint" ? multipointActionRequest(device) : null);
}

function noiseControlRequest(device, mode) {
    const capabilities = device.capabilities || ({});
    const control = (device.fast_pair && device.fast_pair.noise_control) || ({});
    const supported = capabilities.can_set_noise_control && (control.settable_modes || []).includes(mode);
    return {
        supported: supported,
        unchanged: control.active_mode === mode,
        status: "Setting " + device.name + " noise control to " + mode + "…"
    };
}

function deviceState(device) {
    if (device.connected) return "Connected";
    if (device.paired) return "Paired";
    if (device.present) return "Available";
    return device.last_seen_ms ? "Recently found" : "Not in range";
}

function hasSignal(device) {
    return device.signal_strength !== null && device.signal_strength !== undefined;
}

function signalLevel(device) {
    if (!hasSignal(device)) return 0;
    const strength = Math.max(0, Math.min(100, Number(device.signal_strength) || 0));
    return strength >= 67 ? 3 : (strength >= 34 ? 2 : 1);
}

function signalLabel(device) {
    if (!hasSignal(device)) return "Unavailable";
    const suffix = device.signal_live ? "" : " · cached";
    return Math.max(0, Math.min(100, Math.round(Number(device.signal_strength) || 0))) + "%" + suffix;
}

function deviceScore(device) {
    return (device.connected ? 10000 : 0)
        + (device.paired ? 1000 : 0)
        + (device.present ? 100 : 0)
        + signalLevel(device) * 10;
}
