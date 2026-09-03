function emptyRadio() {
    return { available: false, operational: false, powered: false, adapter_count: 0,
        rfkill_present: false, soft_blocked: false, hard_blocked: false };
}

function radioForSnapshot(snapshot: any) {
    if (snapshot.radio)
        return snapshot.radio;
    const adapters = snapshot.adapters || [];
    const powered = adapters.some(function (adapter: any) { return adapter.powered; });
    return { available: adapters.length > 0, operational: powered, powered: powered,
        adapter_count: adapters.length, rfkill_present: false, soft_blocked: false, hard_blocked: false };
}

function activeRequests(snapshot: any, groupName: any) {
    const group = snapshot ? snapshot[groupName] : null;
    return group && Array.isArray(group.active) ? group.active : [];
}

function requestState(snapshot: any) {
    const operations = activeRequests(snapshot, "operations");
    const scans = activeRequests(snapshot, "scans");
    const pairing = activeRequests(snapshot, "pairing");
    return {
        operations: operations,
        activeScan: scans.length > 0 ? scans[0] : null,
        pairingPrompt: pairing.length > 0 ? pairing[pairing.length - 1] : null
    };
}

function pairingStatus(prompt: any, envelope: any) {
    if (prompt)
        return prompt.response_required
            ? "Pairing confirmation required" : "Complete pairing on the Bluetooth device";
    return envelope.data && envelope.data.reason === "timeout"
        ? "Bluetooth pairing request timed out" : "";
}

function pairingTransition(currentPrompt: any, envelope: any) {
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

function isActiveOperation(operation: any) {
    return !!operation && ["queued", "running"].includes(operation.state);
}

function isTerminalOperation(operation: any) {
    return !!operation && ["completed", "failed", "cancelled"].includes(operation.state);
}

function operationEndsPairing(operation: any, prompt: any) {
    return isTerminalOperation(operation) && !!prompt && prompt.device_key === operation.device_key;
}

function withoutMatchingOperation(current: any, requestId: any) {
    return current && current.request_id === requestId ? null : current;
}

function shouldRescanAfterOperation(operation: any, uiActive: any, powered: any, scanning: any) {
    return !!operation && operation.operation === "pair" && operation.state === "failed"
        && !!operation.error && operation.error.code === "device-unavailable"
        && uiActive && powered && !scanning;
}

function isKnownDevice(device: any) {
    return !device.blocked && (device.paired || device.connected);
}

function isDiscoverableDevice(device: any, showRecent: any) {
    return device.blocked || device.paired || device.connected || device.present || showRecent;
}

function deviceBaseName(device: any) {
    return [device.name, device.remote_name, "Bluetooth device"].find(Boolean);
}
function adapterDisplayName(adapter: any) {
    return [adapter.alias, adapter.name, "adapter"].find(Boolean);
}
function deviceDisplayName(device: any, devices: any, adapters: any) {
    const base = deviceBaseName(device);
    const duplicate = devices.some(function (candidate: any) {
        return candidate.key !== device.key && deviceBaseName(candidate) === base;
    });
    if (!duplicate)
        return base;
    const adapter = adapters.find(function (candidate: any) {
        return candidate.key === device.adapter_key;
    });
    return base + " · " + adapterDisplayName(adapter || ({}));
}

function devicesForView(devices: any, scope: any, policy: any) {
    const showRecent = !!policy && !!policy.show_recent_devices;
    const predicate = scope === "all"
        ? function (device: any) { return isDiscoverableDevice(device, showRecent); }
        : isKnownDevice;
    return (devices || []).filter(predicate);
}

function adapterLabel(adapter: any) {
    return adapter.alias || adapter.name || "Bluetooth adapter";
}

function radioStatus(radio: any, searchAllDevices: any, scanning: any, count: any) {
    const state = radio || ({});
    if (state.hard_blocked) return "Bluetooth is disabled by a hardware switch";
    if (state.soft_blocked) return "Bluetooth is disabled by rfkill";
    if (!state.available || Number(state.adapter_count || 0) === 0) return "No Bluetooth adapters available";
    if (!state.powered) return "Bluetooth is off";
    if (searchAllDevices) return scanning ? count + " Bluetooth devices · scanning…" : count + " Bluetooth devices";
    return count + " devices in My Devices";
}

function retainedAdapterKey(adapters: any, currentKey: any) {
    const retained = adapters.some(function (adapter: any) { return adapter.key === currentKey; });
    return retained || adapters.length === 0 ? currentKey : adapters[0].key;
}

function shouldStartScan(uiActive: any, powered: any, scanning: any, requested: any) {
    return uiActive && powered && !scanning && !requested;
}

function completedCallStatus(id: any, powered: any, currentStatus: any) {
    const messages: Record<string, any> = ({
        power: powered ? "Bluetooth turned on" : "Bluetooth turned off",
        "scan-start": "Scanning for Bluetooth devices…",
        "scan-stop": "Bluetooth scan stopped",
        "pairing-response": "Pairing response sent"
    });
    if (messages[id]) return messages[id];
    if (id.indexOf("cancel-scan-") === 0) return messages["scan-stop"];
    return id.indexOf("device-") === 0 ? "Bluetooth device updated" : currentStatus;
}

function scanTransition(activeScan: any, scan: any, deviceCount: any, currentStatus: any) {
    if (!scan || !scan.request_id)
        return null;
    if (scan.state === "running")
        return { activeScan: scan, snapshot: scan.snapshot || null,
            status: "Scanning for Bluetooth devices…" };
    const retained = activeScan && activeScan.request_id !== scan.request_id ? activeScan : null;
    return { activeScan: retained, snapshot: scan.snapshot || null,
        status: scanCompletionStatus(scan, deviceCount, currentStatus) };
}

function scanCompletionStatus(scan: any, deviceCount: any, currentStatus: any) {
    const messages: Record<string, any> = ({
        completed: deviceCount + " Bluetooth devices · scan complete",
        cancelled: "Bluetooth scan stopped",
        failed: (scan.error && scan.error.message) || "Bluetooth scan failed"
    });
    return messages[scan.state] || currentStatus;
}

function operationCompletionStatus(operation: any, deviceName: any) {
    if (operation.state === "completed") return deviceName + " updated";
    if (operation.state === "cancelled") return "Bluetooth operation cancelled";
    return (operation.error && operation.error.message) || "Bluetooth operation failed";
}

function activeOperationStatus(operation: any, deviceName: any) {
    return operation.operation.charAt(0).toUpperCase() + operation.operation.slice(1) + " " + deviceName + "…";
}

function operationTransition(activeOperation: any, pairingPrompt: any, operation: any, deviceName: any, uiActive: any, powered: any, scanning: any) {
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

const directOperations: Record<string, string> = ({ pair: "pair", connect: "connect", disconnect: "disconnect", forget: "remove" });
const toggleOperations: Record<string, { operation: string; field: string }> = ({
    trusted: { operation: "set-trusted", field: "trusted" },
    wake: { operation: "set-wake-allowed", field: "wake_allowed" },
    blocked: { operation: "set-blocked", field: "blocked" }
});

function directActionRequest(actionId: any, device: any, trustAfterPair: any) {
    const operation = directOperations[actionId];
    if (!operation)
        return null;
    const verb = actionId === "forget" ? "Forgetting" : operation.charAt(0).toUpperCase() + operation.slice(1);
    return { operation: operation,
        values: operation === "pair" ? { trust_after_pair: trustAfterPair } : ({}),
        status: verb + " " + device.name + "…" };
}

function toggleActionRequest(actionId: any, device: any) {
    const toggle = toggleOperations[actionId];
    if (!toggle)
        return null;
    const values: Record<string, any> = ({});
    values[toggle.field] = !device[toggle.field];
    return { operation: toggle.operation, values: values, status: "" };
}

function multipointActionRequest(device: any) {
    const multipoint = (device.fast_pair && device.fast_pair.multipoint) || ({});
    return { operation: "set-multipoint", values: { enabled: !multipoint.enabled },
        status: (multipoint.enabled ? "Disabling" : "Enabling") + " multipoint for " + device.name + "…" };
}

function deviceActionRequest(actionId: any, device: any, trustAfterPair: any) {
    return directActionRequest(actionId, device, trustAfterPair)
        || toggleActionRequest(actionId, device)
        || (actionId === "multipoint" ? multipointActionRequest(device) : null);
}

function deviceState(device: any) {
    if (device.blocked) return "Blocked";
    if (device.connected) return "Connected";
    if (device.paired) return "Paired";
    if (device.present) return "Available";
    return device.last_seen_ms ? "Recently found" : "Not in range";
}

function hasSignal(device: any) {
    return device.signal_strength !== null && device.signal_strength !== undefined;
}

function signalLevel(device: any) {
    if (!hasSignal(device)) return 0;
    const strength = Math.max(0, Math.min(100, Number(device.signal_strength) || 0));
    return strength >= 67 ? 3 : (strength >= 34 ? 2 : 1);
}

function signalLabel(device: any) {
    if (!hasSignal(device)) return "Unavailable";
    const suffix = device.signal_live ? "" : " · cached";
    return Math.max(0, Math.min(100, Math.round(Number(device.signal_strength) || 0))) + "%" + suffix;
}

function deviceScore(device: any) {
    return (device.connected ? 10000 : 0)
        + (device.paired ? 1000 : 0)
        + (device.present ? 100 : 0)
        + signalLevel(device) * 10;
}
