.pragma library

"use strict";
function emptyRadio() {
    return { available: false, operational: false, powered: false, adapter_count: 0,
        rfkill_present: false, soft_blocked: false, hard_blocked: false };
}
function radioForSnapshot(snapshot) {
    if (snapshot.radio)
        return snapshot.radio;
    const adapters = snapshot.adapters || [];
    const powered = adapters.some(function (adapter) { return adapter.powered; });
    return { available: adapters.length > 0, operational: powered, powered: powered,
        adapter_count: adapters.length, rfkill_present: false, soft_blocked: false, hard_blocked: false };
}
function activeRequests(snapshot, groupName) {
    const group = snapshot ? snapshot[groupName] : null;
    return group && Array.isArray(group.active) ? group.active : [];
}
function requestState(snapshot) {
    const operations = activeRequests(snapshot, "operations");
    const scans = activeRequests(snapshot, "scans");
    const pairing = activeRequests(snapshot, "pairing");
    return {
        operations: operations,
        activeScan: scans.length > 0 ? scans[0] : null,
        pairingPrompts: pairing,
        pairingPrompt: pairing.length > 0 ? pairing[0] : null
    };
}
function pairingStatus(prompt, envelope) {
    if (prompt)
        return prompt.response_required
            ? "Pairing confirmation required" : "Complete pairing on the Bluetooth device";
    return envelope.data && envelope.data.reason === "timeout"
        ? "Bluetooth pairing request timed out" : "";
}
function pairingQueue(prompts, envelope) {
    const event = envelope || ({});
    const prompt = event.data || ({});
    const current = prompts || [];
    if (!prompt.request_id)
        return current;
    if (["cancelled", "answered"].includes(event.event))
        return current.filter(function (item) { return item.request_id !== prompt.request_id; });
    if (!["requested", "display"].includes(event.event))
        return current;
    const display = event.event === "display";
    const index = current.findIndex(function (item) {
        return item.request_id === prompt.request_id
            || (display && item.device_key === prompt.device_key && item.kind === prompt.kind);
    });
    return index < 0 ? current.concat([prompt])
        : current.map(function (item, i) { return i === index ? prompt : item; });
}
function isActiveOperation(operation) {
    return !!operation && ["queued", "running"].includes(operation.state);
}
function shouldRescanAfterOperation(operation, uiActive, powered, scanning) {
    return !!operation && operation.operation === "pair" && operation.state === "failed"
        && !!operation.error && operation.error.code === "device-unavailable"
        && uiActive && powered && !scanning;
}
function isKnownDevice(device) {
    return !device.blocked && (device.paired || device.connected);
}
function isDiscoverableDevice(device, showRecent) {
    return device.blocked || device.paired || device.connected || device.present || showRecent;
}
function deviceBaseName(device) {
    return [device.name, device.remote_name, "Bluetooth device"].find(Boolean);
}
function adapterDisplayName(adapter) {
    return [adapter.alias, adapter.name, "adapter"].find(Boolean);
}
function deviceDisplayName(device, devices, adapters) {
    const base = deviceBaseName(device);
    const duplicate = devices.some(function (candidate) {
        return candidate.key !== device.key && deviceBaseName(candidate) === base;
    });
    if (!duplicate)
        return base;
    const adapter = adapters.find(function (candidate) {
        return candidate.key === device.adapter_key;
    });
    return base + " · " + adapterDisplayName(adapter || ({}));
}
function devicesForView(devices, scope, policy) {
    const showRecent = !!policy && !!policy.show_recent_devices;
    const predicate = scope === "all"
        ? function (device) { return isDiscoverableDevice(device, showRecent); }
        : isKnownDevice;
    const showBlocked = !!policy && !!policy.show_blocked_devices;
    return (devices || []).filter(function (device) {
        if (device.blocked)
            return showBlocked && (scope === "all" || device.paired || device.connected);
        return predicate(device);
    });
}
function adapterLabel(adapter) {
    return adapter.alias || adapter.name || "Bluetooth adapter";
}
function radioStatus(radio, searchAllDevices, scanning, count) {
    const state = radio || ({});
    if (state.hard_blocked)
        return "Bluetooth is disabled by a hardware switch";
    if (state.soft_blocked)
        return "Bluetooth is disabled by rfkill";
    if (!state.available || Number(state.adapter_count || 0) === 0)
        return "No Bluetooth adapters available";
    if (!state.powered)
        return "Bluetooth is off";
    if (searchAllDevices)
        return scanning ? count + " Bluetooth devices · scanning…" : count + " Bluetooth devices";
    return count + " devices in My Devices";
}
function retainedAdapterKey(adapters, currentKey) {
    const retained = adapters.some(function (adapter) { return adapter.key === currentKey; });
    return retained || adapters.length === 0 ? currentKey : adapters[0].key;
}
function shouldStartScan(uiActive, powered, scanning, requested) {
    return uiActive && powered && !scanning && !requested;
}
function completedCallStatus(id, powered, currentStatus) {
    const messages = ({
        power: powered ? "Bluetooth turned on" : "Bluetooth turned off",
        "scan-start": "Scanning for Bluetooth devices…",
        "scan-stop": "Bluetooth scan stopped",
        "pairing-response": "Pairing response sent"
    });
    if (messages[id])
        return messages[id];
    if (id.indexOf("cancel-scan-") === 0)
        return messages["scan-stop"];
    return id.indexOf("device-") === 0 ? "Bluetooth device updated" : currentStatus;
}
function scanTransition(activeScan, scan, deviceCount, currentStatus) {
    if (!scan || !scan.request_id)
        return null;
    if (scan.state === "running")
        return { activeScan: scan, snapshot: scan.snapshot || null,
            status: "Scanning for Bluetooth devices…" };
    const retained = activeScan && activeScan.request_id !== scan.request_id ? activeScan : null;
    return { activeScan: retained, snapshot: scan.snapshot || null,
        status: scanCompletionStatus(scan, deviceCount, currentStatus) };
}
function scanCompletionStatus(scan, deviceCount, currentStatus) {
    const messages = ({
        completed: deviceCount + " Bluetooth devices · scan complete",
        cancelled: "Bluetooth scan stopped",
        failed: (scan.error && scan.error.message) || "Bluetooth scan failed"
    });
    return messages[scan.state] || currentStatus;
}
function operationCompletionStatus(operation, deviceName) {
    if (operation.state === "completed")
        return deviceName + " updated";
    if (operation.state === "cancelled")
        return "Bluetooth operation cancelled";
    return (operation.error && operation.error.message) || "Bluetooth operation failed";
}
function activeOperationStatus(operation, deviceName) {
    return operation.operation.charAt(0).toUpperCase() + operation.operation.slice(1) + " " + deviceName + "…";
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
        values: operation === "pair" && !device.policy ? { trust_after_pair: trustAfterPair } : ({}),
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
function audioSwitchStatus(event) {
    if (!event)
        return "No switch reported";
    const activity = event.reason === "call" ? "Call" : (event.reason === "media" ? "Media" : "Audio");
    const target = event.target === "this-device" ? "this computer"
        : (event.target === "another-device" ? "another connected device" : "an unknown device");
    return activity + " switched to " + target;
}
function deviceState(device) {
    if (device.blocked)
        return "Blocked";
    if (device.connected)
        return "Connected";
    if (device.paired)
        return "Paired";
    if (device.present)
        return "Available";
    return device.last_seen_ms ? "Recently found" : "Not in range";
}
function hasSignal(device) {
    return device.signal_strength !== null && device.signal_strength !== undefined;
}
function signalLevel(device) {
    if (!hasSignal(device))
        return 0;
    const strength = Math.max(0, Math.min(100, Number(device.signal_strength) || 0));
    return strength >= 67 ? 3 : (strength >= 34 ? 2 : 1);
}
function signalLabel(device) {
    if (!hasSignal(device))
        return "Unavailable";
    const suffix = device.signal_live ? "" : " · cached";
    return Math.max(0, Math.min(100, Math.round(Number(device.signal_strength) || 0))) + "%" + suffix;
}
function deviceScore(device) {
    return (device.connected ? 10000 : 0)
        + (device.paired ? 1000 : 0)
        + (device.present ? 100 : 0)
        + signalLevel(device) * 10;
}
