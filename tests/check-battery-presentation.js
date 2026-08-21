#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

function equal(actual, expected, message) {
    if (JSON.stringify(actual) !== JSON.stringify(expected))
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

equal(context.duration(7500), "2h 5m", "duration formatting");
equal(context.energy(1250), "1.25 Wh", "energy formatting");
equal(context.energy(42), "42.0 mWh", "small energy formatting");
equal(context.stateLabel({ available: true, charging: true }), "Charging", "charging state");
equal(context.stateLabel({ available: true, plugged: false }), "On battery", "discharging state");
equal(context.stateLabel({ available: true, state: "charge-paused", plugged: true }),
    "Charging paused at limit", "charge limit state");
equal(context.stateLabel({ available: true, state: "charging-inhibited", plugged: true }),
    "Charging inhibited", "inhibited state");
equal(context.protectionRange({ supported: true, start_percent: 75, end_percent: 80 }),
    "75–80%", "observed protection range");
equal(context.desiredRange({ desired_start_percent: 70, desired_end_percent: 85 }),
    "70–85%", "desired protection range");
equal(context.thresholdRangeValid(75, 80), true, "valid threshold range");
equal(context.thresholdRangeValid(80, 80), false, "equal thresholds rejected");
equal(context.alertRangeValid(25, 12), true, "valid alert range");
equal(context.alertRangeValid(10, 12), false, "critical above warning rejected");
equal(context.deviceName({ vendor: "Sunwoda", model: "5B11" }),
    "Sunwoda 5B11", "device identity");
equal(context.profileName("power-saver"), "Power saver", "power profile label");
equal(context.actionName("amdgpu_panel_power"), "Amdgpu Panel Power", "power action label");
equal(context.holdSummary({ application_id: "org.example.Build", profile: "performance",
    reason: "Compiling" }), "org.example.Build holds Performance: Compiling", "profile hold summary");
equal(context.calibrationLabel({ kind: "calibration", phase: "discharging" }),
    "Calibration: force-discharging to 1%", "calibration discharge phase");
equal(context.calibrationLabel({ kind: "calibration", phase: "charging" }),
    "Calibration: charging fully before restoring thresholds", "calibration charge phase");
equal(context.sleepCapabilityAvailable("challenge"), true, "authorizable sleep capability");
equal(context.sleepCapabilityAvailable("no"), false, "unavailable sleep capability");
equal(context.inhibitorSummary({ who: "Backup", what: "sleep", why: "Writing snapshot" }),
    "Backup may delay sleep: Writing snapshot", "sleep inhibitor summary");

console.log("battery presentation: formatting and policy validation passed");
