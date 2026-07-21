#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const flowPath = process.argv[2];
if (!flowPath)
    throw new Error("usage: check-bluetooth-lifecycle.js <BluetoothFlow.js>");

const source = fs.readFileSync(flowPath, "utf8").replace(/^\.pragma library\s*/, "");
const flow = {};
vm.createContext(flow);
vm.runInContext(source, flow, { filename: flowPath });

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
expect("cached unpaired device is recently found", flow.deviceState({ paired: false, connected: false, present: false, last_seen_ms: 123 }) === "Recently found");
expect("strong signal uses three bars", flow.signalLevel({ signal_strength: 80 }) === 3);
expect("zero signal still uses one bar", flow.signalLevel({ signal_strength: 0 }) === 1);
expect("missing signal uses no bars", flow.signalLevel({ signal_strength: null }) === 0);
expect("cached signal is labelled", flow.signalLabel({ signal_strength: 50, signal_live: false }) === "50% · cached");
expect("small signal changes share a stable rank", flow.deviceScore({ present: true, signal_strength: 40 }) === flow.deviceScore({ present: true, signal_strength: 60 }));
expect("unavailable cached pairing triggers scan", flow.shouldRescanAfterOperation({ operation: "pair", state: "failed", error: { code: "device-unavailable" } }, true, true, false));
expect("other operation failures do not trigger scan", !flow.shouldRescanAfterOperation({ operation: "connect", state: "failed", error: { code: "device-unavailable" } }, true, true, false));
expect("failed transfer is terminal", flow.isTerminalTransfer({ status: "error" }));
expect("active transfer is not terminal", !flow.isTerminalTransfer({ status: "progress" }));

console.log(`Bluetooth lifecycle: ${checks} checks passed`);
