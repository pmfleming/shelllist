interface Radio {
    available?: boolean;
    operational?: boolean;
    powered?: boolean;
    adapter_count?: number;
    rfkill_present?: boolean;
    soft_blocked?: boolean;
    hard_blocked?: boolean;
}
interface Adapter {
    key: string;
    alias?: string;
    name?: string;
    powered?: boolean;
}
interface Device {
    key: string;
    adapter_key?: string;
    name?: string;
    remote_name?: string;
    blocked?: boolean;
    paired?: boolean;
    connected?: boolean;
    present?: boolean;
    trusted?: boolean;
    wake_allowed?: boolean;
    last_seen_ms?: number | null;
    signal_strength?: number | null;
    signal_live?: boolean;
    policy?: unknown;
    fast_pair?: { multipoint?: { enabled?: boolean } } | null;
}
interface DevicePolicy {
    show_recent_devices?: boolean;
    show_blocked_devices?: boolean;
}
interface RequestError {
    code?: string;
    message?: string;
}
interface Operation {
    operation: string;
    state: string;
    error?: RequestError | null;
}
interface PairingPrompt {
    request_id?: string;
    device_key?: string;
    kind?: string;
    response_required?: boolean;
}
interface Scan {
    request_id?: string;
    state?: string;
    snapshot?: unknown;
    error?: RequestError | null;
}
interface Envelope<T> {
    event?: string;
    data?: T;
}
interface ActiveGroup {
    active?: unknown[];
}
interface Snapshot {
    radio?: Radio;
    adapters?: Adapter[];
    operations?: ActiveGroup;
    scans?: ActiveGroup;
    pairing?: ActiveGroup;
}
interface ActionRequest {
    operation: string;
    values: Record<string, unknown>;
    status: string;
}
type Maybe<T> = T | null | undefined;

function emptyRadio(): Radio {
    return { available: false, operational: false, powered: false, adapter_count: 0,
        rfkill_present: false, soft_blocked: false, hard_blocked: false };
}

function radioForSnapshot(snapshot: Snapshot): Radio {
    if (snapshot.radio)
        return snapshot.radio;
    const adapters = snapshot.adapters || [];
    const powered = adapters.some(function (adapter: Adapter) { return adapter.powered; });
    return { available: adapters.length > 0, operational: powered, powered: powered,
        adapter_count: adapters.length, rfkill_present: false, soft_blocked: false, hard_blocked: false };
}

function activeRequests(snapshot: Maybe<Snapshot>, groupName: "operations" | "scans" | "pairing"): unknown[] {
    const group = snapshot ? snapshot[groupName] : null;
    return group && Array.isArray(group.active) ? group.active : [];
}

function requestState(snapshot: Maybe<Snapshot>) {
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

function pairingStatus(prompt: Maybe<PairingPrompt>, envelope: Envelope<{ reason?: string }>) {
    if (prompt)
        return prompt.response_required
            ? "Pairing confirmation required" : "Complete pairing on the Bluetooth device";
    return envelope.data && envelope.data.reason === "timeout"
        ? "Bluetooth pairing request timed out" : "";
}

function pairingQueue(prompts: Maybe<PairingPrompt[]>, envelope: Maybe<Envelope<PairingPrompt>>): PairingPrompt[] {
    const event: Envelope<PairingPrompt> = envelope || ({});
    const prompt: PairingPrompt = event.data || ({});
    const current = prompts || [];
    if (!prompt.request_id) return current;
    if (["cancelled", "answered"].includes(String(event.event)))
        return current.filter(function (item: PairingPrompt) { return item.request_id !== prompt.request_id; });
    if (!["requested", "display"].includes(String(event.event))) return current;
    const display = event.event === "display";
    const index = current.findIndex(function (item: PairingPrompt) {
        return item.request_id === prompt.request_id
            || (display && item.device_key === prompt.device_key && item.kind === prompt.kind);
    });
    return index < 0 ? current.concat([prompt])
        : current.map(function (item: PairingPrompt, i: number) { return i === index ? prompt : item; });
}

function isActiveOperation(operation: Maybe<Operation>) {
    return !!operation && ["queued", "running"].includes(operation.state);
}

function shouldRescanAfterOperation(operation: Maybe<Operation>, uiActive: boolean, powered: boolean, scanning: boolean) {
    return !!operation && operation.operation === "pair" && operation.state === "failed"
        && !!operation.error && operation.error.code === "device-unavailable"
        && uiActive && powered && !scanning;
}

function isKnownDevice(device: Device) {
    return !device.blocked && (device.paired || device.connected);
}

function isDiscoverableDevice(device: Device, showRecent: boolean) {
    return device.blocked || device.paired || device.connected || device.present || showRecent;
}

function deviceBaseName(device: Device) {
    return [device.name, device.remote_name, "Bluetooth device"].find(Boolean);
}
function adapterDisplayName(adapter: Partial<Adapter>) {
    return [adapter.alias, adapter.name, "adapter"].find(Boolean);
}
function deviceDisplayName(device: Device, devices: Device[], adapters: Adapter[]) {
    const base = deviceBaseName(device);
    const duplicate = devices.some(function (candidate: Device) {
        return candidate.key !== device.key && deviceBaseName(candidate) === base;
    });
    if (!duplicate)
        return base;
    const adapter = adapters.find(function (candidate: Adapter) {
        return candidate.key === device.adapter_key;
    });
    return base + " · " + adapterDisplayName(adapter || ({}));
}

function devicesForView(devices: Maybe<Device[]>, scope: string, policy: Maybe<DevicePolicy>) {
    const showRecent = !!policy && !!policy.show_recent_devices;
    const predicate = scope === "all"
        ? function (device: Device) { return isDiscoverableDevice(device, showRecent); }
        : isKnownDevice;
    const showBlocked = !!policy && !!policy.show_blocked_devices;
    return (devices || []).filter(function (device: Device) {
        if (device.blocked) return showBlocked && (scope === "all" || device.paired || device.connected);
        return predicate(device);
    });
}

function adapterLabel(adapter: Partial<Adapter>) {
    return adapter.alias || adapter.name || "Bluetooth adapter";
}

function radioStatus(radio: Maybe<Radio>, searchAllDevices: boolean, scanning: boolean, count: number) {
    const state: Radio = radio || ({});
    if (state.hard_blocked) return "Bluetooth is disabled by a hardware switch";
    if (state.soft_blocked) return "Bluetooth is disabled by rfkill";
    if (!state.available || Number(state.adapter_count || 0) === 0) return "No Bluetooth adapters available";
    if (!state.powered) return "Bluetooth is off";
    if (searchAllDevices) return scanning ? count + " Bluetooth devices · scanning…" : count + " Bluetooth devices";
    return count + " devices in My Devices";
}

function retainedAdapterKey(adapters: Adapter[], currentKey: string) {
    const retained = adapters.some(function (adapter: Adapter) { return adapter.key === currentKey; });
    return retained || adapters.length === 0 ? currentKey : adapters[0].key;
}

function shouldStartScan(uiActive: boolean, powered: boolean, scanning: boolean, requested: boolean) {
    return uiActive && powered && !scanning && !requested;
}

function completedCallStatus(id: string, powered: boolean, currentStatus: string) {
    const messages: Record<string, string> = ({
        power: powered ? "Bluetooth turned on" : "Bluetooth turned off",
        "scan-start": "Scanning for Bluetooth devices…",
        "scan-stop": "Bluetooth scan stopped",
        "pairing-response": "Pairing response sent"
    });
    if (messages[id]) return messages[id];
    if (id.indexOf("cancel-scan-") === 0) return messages["scan-stop"];
    return id.indexOf("device-") === 0 ? "Bluetooth device updated" : currentStatus;
}

function scanTransition(activeScan: Maybe<Scan>, scan: Maybe<Scan>, deviceCount: number, currentStatus: string) {
    if (!scan || !scan.request_id)
        return null;
    if (scan.state === "running")
        return { activeScan: scan, snapshot: scan.snapshot || null,
            status: "Scanning for Bluetooth devices…" };
    const retained = activeScan && activeScan.request_id !== scan.request_id ? activeScan : null;
    return { activeScan: retained, snapshot: scan.snapshot || null,
        status: scanCompletionStatus(scan, deviceCount, currentStatus) };
}

function scanCompletionStatus(scan: Scan, deviceCount: number, currentStatus: string) {
    const messages: Record<string, string> = ({
        completed: deviceCount + " Bluetooth devices · scan complete",
        cancelled: "Bluetooth scan stopped",
        failed: (scan.error && scan.error.message) || "Bluetooth scan failed"
    });
    return messages[String(scan.state)] || currentStatus;
}

function operationCompletionStatus(operation: Operation, deviceName: string) {
    if (operation.state === "completed") return deviceName + " updated";
    if (operation.state === "cancelled") return "Bluetooth operation cancelled";
    return (operation.error && operation.error.message) || "Bluetooth operation failed";
}

function activeOperationStatus(operation: Operation, deviceName: string) {
    return operation.operation.charAt(0).toUpperCase() + operation.operation.slice(1) + " " + deviceName + "…";
}

const directOperations: Record<string, string> = ({ pair: "pair", connect: "connect", disconnect: "disconnect", forget: "remove" });
const toggleOperations: Record<string, { operation: string; field: string }> = ({
    trusted: { operation: "set-trusted", field: "trusted" },
    wake: { operation: "set-wake-allowed", field: "wake_allowed" },
    blocked: { operation: "set-blocked", field: "blocked" }
});

function directActionRequest(actionId: string, device: Device, trustAfterPair: boolean): ActionRequest | null {
    const operation = directOperations[actionId];
    if (!operation)
        return null;
    const verb = actionId === "forget" ? "Forgetting" : operation.charAt(0).toUpperCase() + operation.slice(1);
    return { operation: operation,
        values: operation === "pair" && !device.policy ? { trust_after_pair: trustAfterPair } : ({}),
        status: verb + " " + device.name + "…" };
}

function toggleActionRequest(actionId: string, device: Device): ActionRequest | null {
    const toggle = toggleOperations[actionId];
    if (!toggle)
        return null;
    const values: Record<string, unknown> = ({});
    values[toggle.field] = !device[toggle.field as keyof Device];
    return { operation: toggle.operation, values: values, status: "" };
}

function multipointActionRequest(device: Device): ActionRequest {
    const multipoint: { enabled?: boolean } = (device.fast_pair && device.fast_pair.multipoint) || ({});
    return { operation: "set-multipoint", values: { enabled: !multipoint.enabled },
        status: (multipoint.enabled ? "Disabling" : "Enabling") + " multipoint for " + device.name + "…" };
}

function deviceActionRequest(actionId: string, device: Device, trustAfterPair: boolean) {
    return directActionRequest(actionId, device, trustAfterPair)
        || toggleActionRequest(actionId, device)
        || (actionId === "multipoint" ? multipointActionRequest(device) : null);
}

function audioSwitchStatus(event: Maybe<{ reason?: string; target?: string }>): string {
    if (!event) return "No switch reported";
    const activity = event.reason === "call" ? "Call" : (event.reason === "media" ? "Media" : "Audio");
    const target = event.target === "this-device" ? "this computer"
        : (event.target === "another-device" ? "another connected device" : "an unknown device");
    return activity + " switched to " + target;
}

function deviceState(device: Device) {
    if (device.blocked) return "Blocked";
    if (device.connected) return "Connected";
    if (device.paired) return "Paired";
    if (device.present) return "Available";
    return device.last_seen_ms ? "Recently found" : "Not in range";
}

function hasSignal(device: Device) {
    return device.signal_strength !== null && device.signal_strength !== undefined;
}

function signalLevel(device: Device) {
    if (!hasSignal(device)) return 0;
    const strength = Math.max(0, Math.min(100, Number(device.signal_strength) || 0));
    return strength >= 67 ? 3 : (strength >= 34 ? 2 : 1);
}

function signalLabel(device: Device) {
    if (!hasSignal(device)) return "Unavailable";
    const suffix = device.signal_live ? "" : " · cached";
    return Math.max(0, Math.min(100, Math.round(Number(device.signal_strength) || 0))) + "%" + suffix;
}

function deviceScore(device: Device) {
    return (device.connected ? 10000 : 0)
        + (device.paired ? 1000 : 0)
        + (device.present ? 100 : 0)
        + signalLevel(device) * 10;
}
