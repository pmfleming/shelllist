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

const modes = helper.modes();
expect("control exposes four canonical modes", modes.length === 4);
expect("modes retain presentation order",
    modes.map(mode => mode.value).join(",") === "transparent,adaptive,noise-cancelling,off");
expect("modes retain user-facing labels",
    modes.map(mode => mode.label).join(",") === "Ambient,Adaptive,Noise cancellation,Off");
for (const mode of modes)
    expect(`${mode.value} artwork exists`, fs.existsSync(path.resolve(bluetoothRoot, mode.image)));

const control = {
    available_modes: ["transparent", "adaptive", "noise-cancelling", "off"],
    settable_modes: ["transparent", "noise-cancelling", "off"]
};
expect("reported noise control is advertised", helper.isAdvertised(control));
expect("empty noise control stays hidden", !helper.isAdvertised({ available_modes: [] }));
expect("settable mode is enabled", helper.isSettable(control, "transparent"));
expect("reported but unsettable mode is disabled", !helper.isSettable(control, "adaptive"));
expect("right navigation skips disabled modes", helper.adjacentSettableIndex(control, 0, 1) === 2);
expect("left navigation stops at the boundary", helper.adjacentSettableIndex(control, 0, -1) === -1);

console.log(`Bluetooth noise control presentation: ${checks} checks passed`);
