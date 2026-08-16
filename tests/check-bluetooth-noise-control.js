#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-bluetooth-noise-control.js <BluetoothNoiseControl.js> [bluetooth-root]");
const bluetoothRoot = process.argv[3] || path.dirname(helperPath);
const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, "");
const helper = {};
vm.createContext(helper);
vm.runInContext(source, helper, { filename: helperPath });

let checks = 0;
function expect(label, condition) {
    ++checks;
    if (!condition)
        throw new Error(label);
}

const control = {
    available_modes: ["transparent", "adaptive", "noise-cancelling", "off"],
    active_mode: "adaptive"
};
const modes = helper.availableModes(control);
expect("control exposes four canonical modes", modes.length === 4);
expect("modes retain user-facing labels",
    modes.map(mode => mode.label).join(",") === "Ambient,Adaptive,Noise cancellation,Off");
for (const mode of modes)
    expect(`${mode.value} artwork exists`, fs.existsSync(path.resolve(bluetoothRoot, mode.image)));
expect("reported noise control is advertised", helper.isAdvertised(control));
expect("empty noise control stays hidden", !helper.isAdvertised({ available_modes: [] }));
expect("available status retains canonical presentation order",
    helper.availableModes(control).map(mode => mode.value).join(",") === "transparent,adaptive,noise-cancelling,off");
expect("unsupported status modes are omitted",
    helper.availableModes({ available_modes: ["off", "transparent"] }).map(mode => mode.value).join(",") === "transparent,off");
expect("reported active mode is selected", helper.isActive(control, "adaptive"));
expect("non-active mode is not selected", !helper.isActive(control, "transparent"));
expect("active status has a user-facing label", helper.activeLabel(control) === "Adaptive");
expect("unknown active status has a safe label", helper.activeLabel({ active_mode: "vendor-mode" }) === "Unknown");

console.log(`Bluetooth noise control presentation: ${checks} checks passed`);
