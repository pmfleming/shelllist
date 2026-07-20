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

expect("completed operation is terminal", flow.isTerminalOperation({ state: "completed" }));
expect("running operation is not terminal", !flow.isTerminalOperation({ state: "running" }));
expect("failed transfer is terminal", flow.isTerminalTransfer({ status: "error" }));
expect("active transfer is not terminal", !flow.isTerminalTransfer({ status: "progress" }));

console.log(`Bluetooth lifecycle: ${checks} checks passed`);
