#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");
const assert = require("node:assert/strict");

const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-bluetooth-noise-control.js <BluetoothNoiseControl.js>");
const helper = {};
vm.createContext(helper);
vm.runInContext(fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, ""), helper);

// The device-page test covers reported modes, image loading and hidden status.
// Mode selection/provisioning are no longer exposed by the project UI.
assert.equal(helper.activeMode({ active_mode: "vendor-mode" }).image, "",
    "unknown active status has no misleading artwork");
console.log("Bluetooth noise control: unknown status passed");
