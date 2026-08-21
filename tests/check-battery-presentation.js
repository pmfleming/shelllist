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
equal(context.stateLabel({ available: true, charging: true }), "Charging", "charging state");
equal(context.stateLabel({ available: true, plugged: false }), "On battery", "discharging state");
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

console.log("battery presentation: formatting and policy validation passed");
