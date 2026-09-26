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

equal(context.localTime(0, -5 * 3600), "19:00", "negative location offset crosses midnight");
equal(context.localTime(0, 5.5 * 3600), "05:30", "fractional location offset");
// The QML solar-time test owns clock updates and missing sunrise/sunset data.
console.log("weather presentation: local time offsets passed");
