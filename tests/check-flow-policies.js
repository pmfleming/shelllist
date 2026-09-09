#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

if (process.argv.length !== 4)
    throw new Error("usage: check-flow-policies.js <BatteryFlow.js> <ClipboardFlow.js>");

function load(path) {
    const context = {};
    vm.createContext(context);
    vm.runInContext(fs.readFileSync(path, "utf8").replace(/^\.pragma library\s*$/m, ""), context);
    return context;
}

// Selection and edit preservation are covered through BatteryController.
const battery = load(process.argv[2]);
assert.equal(battery.energyRequest("week", false, 120000, 100000, 0), null,
    "fresh energy request is cached");
assert.ok(battery.energyRequest("week", true, 120000, 100000, 0),
    "explicit refresh bypasses the cache");

const clipboard = load(process.argv[3]);
const first = clipboard.rememberTerminal({ id: "op-1", status: "completed" }, {}, 64);
assert.ok(!first.duplicate, "first terminal event is handled");
assert.ok(clipboard.rememberTerminal({ id: "op-1", status: "completed" }, first.handled, 64).duplicate,
    "a repeated completion must not repeat its effects");
console.log("flow policies: refresh caching and duplicate completion suppression passed");
