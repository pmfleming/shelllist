#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const flowPath = process.argv[2];
const apiPath = process.argv[3];
const protocolPath = process.argv[4];
if (!flowPath || !apiPath)
    throw new Error("usage: check-bluetooth-lifecycle.js <BluetoothFlow.js> <BtApi.js> [BtProtocol.generated.js]");

function loadLibrary(file) {
    let source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*/, "");
    const library = {};
    const importMatch = source.match(/^\.import\s+"([^"]+)"\s+as\s+Protocol$/m);
    if (importMatch) {
        const protocol = {};
        vm.createContext(protocol);
        vm.runInContext(
            fs.readFileSync(protocolPath || path.resolve(path.dirname(file), importMatch[1]), "utf8")
                .replace(/^\.pragma library\s*/, ""),
            protocol
        );
        library.Protocol = protocol;
        source = source.replace(/^\.import.*$/m, "");
    }
    vm.createContext(library);
    vm.runInContext(source, library, { filename: file });
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
// Concurrent prompt/input preservation is exercised through BluetoothController.
let queue = flow.pairingQueue([], requested);
queue = flow.pairingQueue(queue, { event: "answered", data: { request_id: "pairing-1" } });
expect("answer removes only matching prompt", queue.length === 0);
queue = flow.pairingQueue([], { event: "display", data: { request_id: "display-1", device_key: "keyboard", kind: "display-passkey", entered: 1 } });
queue = flow.pairingQueue(queue, { event: "display", data: { request_id: "display-2", device_key: "keyboard", kind: "display-passkey", entered: 2 } });
expect("display progress replaces rather than queues", queue.length === 1 && queue[0].entered === 2);
const transition = flow.pairingTransition(requested.data, {
    event: "cancelled",
    data: { request_id: "pairing-1", reason: "timeout" }
});
expect("matching timeout closes prompt", transition.changed && transition.prompt === null);

expect("scan failure exposes its error", flow.scanCompletionStatus({ state: "failed", error: { message: "radio failed" } }, 0, "Scanning") === "radio failed");
const myDevices = flow.devicesForView([
    { key: "paired", paired: true, blocked: false },
    { key: "nearby", paired: false, blocked: false, present: true },
    { key: "blocked", paired: true, blocked: true }
], "mine", {});
expect("My Devices excludes nearby and blocked devices", myDevices.length === 1 && myDevices[0].key === "paired");
const allDevices = flow.devicesForView([
    { key: "paired", paired: true, blocked: false, present: true },
    { key: "nearby", paired: false, blocked: false, present: true },
    { key: "blocked", paired: false, blocked: true, present: false },
    { key: "recent", paired: false, blocked: false, present: false }
], "all", { show_recent_devices: true, show_blocked_devices: true });
expect("Search all includes paired, nearby, blocked, and retained devices", allDevices.length === 4);
const currentDevices = flow.devicesForView(allDevices, "all", { show_recent_devices: false });
expect("Search all honors hidden blocked devices", !currentDevices.some(device => device.key === "blocked"));
expect("blocked paired devices can be managed from My Devices", flow.devicesForView([{key: "blocked", paired: true, blocked: true}], "mine", {show_blocked_devices: true}).length === 1);
expect("Search all can hide an unblocked stale device", !currentDevices.some(device => device.key === "recent"));
expect("other operation failures do not trigger scan", !flow.shouldRescanAfterOperation({ operation: "connect", state: "failed", error: { code: "device-unavailable" } }, true, true, false));
const activeOperation = flow.operationTransition(null, null, {
    request_id: "operation-1", operation: "connect", state: "running"
}, "Headset", true, true, false);
const failedPair = flow.operationTransition(activeOperation.activeOperation, requested.data, {
    request_id: "operation-1", operation: "pair", state: "failed", device_key: "device-1",
    error: { code: "device-unavailable" }
}, "Headset", true, true, false);
expect("failed unavailable pair transitions to rescan", failedPair.rescan && failedPair.clearPairing && failedPair.activeOperation === null);
const activeLifecycle = api.lifecycleState({ request_id: "operation-1" }, {}, {}, "running", ["completed"]);
const finishedLifecycle = api.lifecycleState({ request_id: "operation-1" }, activeLifecycle.active, {}, "completed", ["completed"]);
expect("backend lifecycle removes terminal requests", !finishedLifecycle.active["operation-1"]);
const pairAction = flow.deviceActionRequest("pair", { name: "Headset" }, true);
expect("pair action retains trust policy", pairAction.operation === "pair" && pairAction.values.trust_after_pair);
expect("unknown device actions are rejected", flow.deviceActionRequest("unknown", {}, false) === null);
console.log(`Bluetooth lifecycle: ${checks} checks passed`);
