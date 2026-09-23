#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const flowPath = process.argv[2];
if (!flowPath)
    throw new Error("usage: check-bluetooth-lifecycle.js <BluetoothFlow.js>");
const flow = vm.createContext({});
vm.runInContext(fs.readFileSync(flowPath, "utf8").replace(/^\.pragma library\s*/, ""), flow,
    { filename: flowPath });

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
expect("other operation failures do not trigger scan", !flow.shouldRescanAfterOperation({ operation: "connect", state: "failed", error: { code: "device-unavailable" } }, true, true, false));
expect("failed unavailable pair requests rescan", flow.shouldRescanAfterOperation({
    operation: "pair", state: "failed", error: { code: "device-unavailable" }
}, true, true, false));
const pairAction = flow.deviceActionRequest("pair", { name: "Headset" }, true);
expect("pair action retains trust policy", pairAction.operation === "pair" && pairAction.values.trust_after_pair);
expect("unknown device actions are rejected", flow.deviceActionRequest("unknown", {}, false) === null);
console.log(`Bluetooth lifecycle: ${checks} checks passed`);
