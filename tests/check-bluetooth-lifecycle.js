#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const flowPath = process.argv[2];
const apiPath = process.argv[3];
if (!flowPath || !apiPath)
    throw new Error("usage: check-bluetooth-lifecycle.js <BluetoothFlow.js> <BtApi.js>");

function loadLibrary(path) {
    const source = fs.readFileSync(path, "utf8").replace(/^\.pragma library\s*/, "");
    const library = {};
    vm.createContext(library);
    vm.runInContext(source, library, { filename: path });
    return library;
}

const flow = loadLibrary(flowPath);
const api = loadLibrary(apiPath);

let checks = 0;
function expect(label, condition) {
    ++checks;
    if (!condition)
        throw new Error(label);
}

const requested = {
    event: "requested",
    data: { request_id: "pairing-1", device_key: "device-1", response_required: true }
};
let transition = flow.pairingTransition(null, requested);
expect("requested prompt opens", transition.changed && transition.prompt.request_id === "pairing-1");

transition = flow.pairingTransition(requested.data, {
    event: "cancelled",
    data: { request_id: "pairing-other", reason: "timeout" }
});
expect("unrelated timeout does not close prompt", !transition.changed && transition.prompt.request_id === "pairing-1");

transition = flow.pairingTransition(requested.data, {
    event: "cancelled",
    data: { request_id: "pairing-1", reason: "timeout" }
});
expect("matching timeout closes prompt", transition.changed && transition.prompt === null);

expect("running operation is active", flow.isActiveOperation({ state: "running" }));
expect("completed operation is terminal", flow.isTerminalOperation({ state: "completed" }));
expect("running operation is not terminal", !flow.isTerminalOperation({ state: "running" }));
expect("terminal pairing operation closes its prompt", flow.operationEndsPairing({ state: "failed", device_key: "device-1" }, requested.data));
expect("preferred adapter is retained", flow.retainedAdapterKey([{ key: "a" }, { key: "b" }], "b") === "b");
expect("missing adapter falls back", flow.retainedAdapterKey([{ key: "a" }], "b") === "a");
expect("initial scan requires an idle powered UI", flow.shouldStartScan(true, true, false, false));
expect("snapshot status reports scanning", flow.snapshotStatus(true, true, 3) === "3 devices · scanning…");
expect("completed calls use a stable status", flow.completedCallStatus("device-connect", true, "Connecting") === "Bluetooth device updated");
expect("scan failure exposes its error", flow.scanCompletionStatus({ state: "failed", error: { message: "radio failed" } }, 0, "Scanning") === "radio failed");
expect("incoming transfer completion names Downloads", flow.transferCompletionStatus({ status: "complete", direction: "incoming", file_name: "photo.jpg" }) === "photo.jpg saved in Downloads");
expect("transfer progress reports percentage", flow.transferProgressStatus({ direction: "outgoing", file_name: "photo.jpg", size: 100, transferred: 25 }) === "Sending photo.jpg · 25%");
expect("cancelled operations have a stable status", flow.operationCompletionStatus({ state: "cancelled" }, "Headset") === "Bluetooth operation cancelled");
expect("cached unpaired device is recently found", flow.deviceState({ paired: false, connected: false, present: false, last_seen_ms: 123 }) === "Recently found");
expect("blocked state takes priority", flow.deviceState({ blocked: true, paired: true, connected: false }) === "Blocked");
const managedDevices = flow.devicesForView([
    { key: "paired", paired: true, blocked: false },
    { key: "nearby", paired: false, blocked: false, present: true },
    { key: "blocked", paired: true, blocked: true }
], "managed", { show_blocked_devices: false });
expect("managed view excludes discovery and hidden blocked devices", managedDevices.length === 1 && managedDevices[0].key === "paired");
const discoveryDevices = flow.devicesForView([
    { key: "paired", paired: true, blocked: false, present: true },
    { key: "nearby", paired: false, blocked: false, present: true },
    { key: "recent", paired: false, blocked: false, present: false }
], "discovery", { show_recent_devices: true });
expect("discovery view excludes paired devices and can retain recent devices", discoveryDevices.length === 2);
expect("radio status distinguishes hardware blocks", flow.radioStatus({ hard_blocked: true }, false, false, 0).includes("hardware switch"));
expect("radio status distinguishes missing adapters", flow.radioStatus({ available: false, adapter_count: 0 }, false, false, 0) === "No Bluetooth adapters available");
expect("strong signal uses three bars", flow.signalLevel({ signal_strength: 80 }) === 3);
expect("zero signal still uses one bar", flow.signalLevel({ signal_strength: 0 }) === 1);
expect("missing signal uses no bars", flow.signalLevel({ signal_strength: null }) === 0);
expect("cached signal is labelled", flow.signalLabel({ signal_strength: 50, signal_live: false }) === "50% · cached");
expect("small signal changes share a stable rank", flow.deviceScore({ present: true, signal_strength: 40 }) === flow.deviceScore({ present: true, signal_strength: 60 }));
expect("unavailable cached pairing triggers scan", flow.shouldRescanAfterOperation({ operation: "pair", state: "failed", error: { code: "device-unavailable" } }, true, true, false));
expect("other operation failures do not trigger scan", !flow.shouldRescanAfterOperation({ operation: "connect", state: "failed", error: { code: "device-unavailable" } }, true, true, false));
expect("failed transfer is terminal", flow.isTerminalTransfer({ status: "error" }));
expect("active transfer is not terminal", !flow.isTerminalTransfer({ status: "progress" }));
const incoming = flow.transferTransition(null, null, {
    request_id: "transfer-1", status: "awaiting-authorization", file_name: "photo.jpg"
});
expect("incoming transfer transition requests authorization", incoming.authorizationRequested && incoming.prompt.request_id === "transfer-1");
const finishedTransfer = flow.transferTransition(incoming.activeTransfer, incoming.prompt, {
    request_id: "transfer-1", status: "complete", direction: "incoming", file_name: "photo.jpg"
});
expect("terminal transfer clears matching state", finishedTransfer.activeTransfer === null && finishedTransfer.prompt === null);
const activeOperation = flow.operationTransition(null, null, {
    request_id: "operation-1", operation: "connect", state: "running"
}, "Headset", true, true, false);
expect("active operation transition retains request", activeOperation.active && activeOperation.activeOperation.request_id === "operation-1");
const failedPair = flow.operationTransition(activeOperation.activeOperation, requested.data, {
    request_id: "operation-1", operation: "pair", state: "failed", device_key: "device-1",
    error: { code: "device-unavailable" }
}, "Headset", true, true, false);
expect("failed unavailable pair transitions to rescan", failedPair.rescan && failedPair.clearPairing && failedPair.activeOperation === null);
expect("response routing preserves protocol priority", api.responseKind({ scan: {}, snapshot: {} }) === "scan");
expect("response routing recognizes audio snapshots", api.responseKind({ audio_devices: [{ device_key: "device-1" }] }) === "audio_devices");
const activeLifecycle = api.lifecycleState({ request_id: "operation-1" }, {}, {}, "running", ["completed"]);
expect("backend lifecycle records active requests", activeLifecycle.active["operation-1"].request_id === "operation-1");
const finishedLifecycle = api.lifecycleState({ request_id: "operation-1" }, activeLifecycle.active, {}, "completed", ["completed"]);
expect("backend lifecycle removes terminal requests", !finishedLifecycle.active["operation-1"]);
const pairAction = flow.deviceActionRequest("pair", { name: "Headset" }, true);
expect("pair action retains trust policy", pairAction.operation === "pair" && pairAction.values.trust_after_pair);
const wakeAction = flow.deviceActionRequest("wake", { wake_allowed: false }, false);
expect("wake action toggles the backend value", wakeAction.operation === "set-wake-allowed" && wakeAction.values.wake_allowed);
expect("unknown device actions are rejected", flow.deviceActionRequest("unknown", {}, false) === null);
const noiseControlDevice = {
    name: "Headset",
    capabilities: { can_set_noise_control: true },
    fast_pair: {
        noise_control: {
            settable_modes: ["transparent", "adaptive", "noise-cancelling", "off"],
            active_mode: "off"
        }
    }
};
for (const mode of ["transparent", "adaptive", "noise-cancelling", "off"])
    expect(`${mode} noise control mode is accepted`, flow.noiseControlRequest(noiseControlDevice, mode).supported);
expect("unknown noise control modes are rejected", !flow.noiseControlRequest(noiseControlDevice, "unknown").supported);
expect("active noise control mode is unchanged", flow.noiseControlRequest(noiseControlDevice, "off").unchanged);

console.log(`Bluetooth lifecycle: ${checks} checks passed`);
