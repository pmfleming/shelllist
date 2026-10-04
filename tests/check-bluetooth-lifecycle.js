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

// Concurrent prompt/input preservation is exercised through BluetoothController.
let queue = flow.pairingQueue([], { event: "display", data: { request_id: "display-1", device_key: "keyboard", kind: "display-passkey", entered: 1 } });
queue = flow.pairingQueue(queue, { event: "display", data: { request_id: "display-2", device_key: "keyboard", kind: "display-passkey", entered: 2 } });
expect("display progress replaces rather than queues", queue.length === 1 && queue[0].entered === 2);

for (let flags = 0; flags < 16; flags++) {
    const device = Object.freeze({blocked: !!(flags & 1), paired: !!(flags & 2), connected: !!(flags & 4), present: !!(flags & 8)});
    for (const scope of ["all", "known", "unknown"])
        for (const policy of [null, {}, {show_blocked_devices: true}, {show_recent_devices: true}, {show_blocked_devices: true, show_recent_devices: true}]) {
            const known = device.paired || device.connected;
            const expected = device.blocked
                ? !!policy?.show_blocked_devices && (scope === "all" || known)
                : known || (scope === "all" && (device.present || !!policy?.show_recent_devices));
            const visible = flow.devicesForView(Object.freeze([device]), scope, policy);
            expect(`visibility ${flags}/${scope}/${JSON.stringify(policy)}`, visible.length === Number(expected));
        }
}
console.log(`Bluetooth lifecycle: ${checks} checks passed`);
