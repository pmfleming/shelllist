#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const vm = require("vm");

let source = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, "");
const durationImport = source.match(/^\.import\s+"([^"]+)"\s+as\s+Duration\s*$/m);
const Duration = {};
vm.createContext(Duration);
vm.runInContext(fs.readFileSync(process.argv[3]
    || path.resolve(path.dirname(process.argv[2]), durationImport[1]), "utf8")
    .replace(/^\.pragma library\s*$/m, ""), Duration);
const context = { Duration };
vm.createContext(context);
vm.runInContext(source.replace(durationImport[0], ""), context);
function equal(actual, expected, message) {
    if (actual !== expected)
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

equal(context.thresholdRangeValid(75, 80), true, "valid threshold range");
equal(context.thresholdRangeValid(80, 80), false, "equal thresholds rejected");
equal(context.alertRangeValid(25, 12), true, "valid alert range");
equal(context.alertRangeValid(10, 12), false, "critical above warning rejected");
console.log("battery presentation: policy validation passed");
