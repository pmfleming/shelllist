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
const sunrise = Date.UTC(2026, 5, 21, 6);
near(context.daylightFraction(sunrise, sunrise + 18 * 3600000), 0.75, "daylight duration");
equal(context.daylightFraction(0, 0), 0, "missing sun times");
equal(context.daylightFraction(sunrise, sunrise - 1), 0, "invalid sun times");
equal(context.daylightFraction(sunrise, sunrise + 30 * 3600000), 1, "daylight ring clamp");
const newMoon = Date.UTC(2000, 0, 6, 18, 14);
equal(context.moonPhase(newMoon).illumination, 0, "known new moon is unlit");
equal(context.moonPhase(newMoon + 29.530588853 * 86400000 / 2).illumination,
    100, "half a lunar cycle later is fully lit");
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
console.log("weather presentation: local times, daylight and rendered moon illumination passed");
