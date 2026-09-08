#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-bluetooth-noise-control.js <BluetoothNoiseControl.js> [bluetooth-root]");
const bluetoothRoot = process.argv[3] || path.dirname(helperPath);
const helper = {};
vm.createContext(helper);
vm.runInContext(fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, ""), helper);
function expect(label, condition) {
    if (!condition) throw new Error(label);
}

const control = { available_modes: ["off", "transparent"], active_mode: "transparent" };
const modes = helper.availableModes(control);
expect("only supported modes are offered", modes.length === 2
    && modes.every(mode => control.available_modes.includes(mode.value)));
for (const mode of modes)
    expect("offered mode artwork exists", fs.existsSync(path.resolve(bluetoothRoot, mode.image)));
expect("reported active mode is selected", helper.isActive(control, "transparent"));
expect("empty noise control stays hidden", !helper.isAdvertised({ available_modes: [] }));
expect("unknown active status has no misleading artwork",
    helper.activeMode({ active_mode: "vendor-mode" }).image === "");
console.log("Bluetooth noise control: supported modes, assets and unknown state passed");
