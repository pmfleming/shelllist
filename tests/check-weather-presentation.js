#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const context = { Date, Number, Math, String };
vm.createContext(context);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, ""), context);
function equal(actual, expected, message) {
    if (actual !== expected)
        throw new Error(`${message}: expected ${expected}, got ${actual}`);
}
function near(actual, expected, message) {
    if (Math.abs(actual - expected) > 0.000001)
        throw new Error(`${message}: expected ${expected}, got ${actual}`);
}

equal(context.localTime(0, -5 * 3600), "19:00", "negative location offset crosses midnight");
equal(context.localTime(0, 5.5 * 3600), "05:30", "fractional location offset");
equal(context.moonPhase, undefined, "astronomical estimates belong to bar-daemon");
// The QML solar-time test owns clock updates and missing sunrise/sunset data.
// Check rendered illumination, not the helper's exact edge coordinates or labels.
for (const fraction of [0.125, 0.625]) {
    let area = 0;
    const steps = 10000;
    for (let step = 0; step < steps; ++step) {
        const bounds = context.moonLitBounds(fraction, -1 + (step + 0.5) * 2 / steps);
        area += (bounds.right - bounds.left) * 2 / steps;
    }
    near(area / Math.PI, (1 - Math.cos(2 * Math.PI * fraction)) / 2,
        `phase ${fraction} rendered illumination`);
}
console.log("weather presentation: local times and rendered moon illumination passed");
