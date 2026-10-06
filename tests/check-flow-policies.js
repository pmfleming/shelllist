#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

if (process.argv.length !== 3)
    throw new Error("usage: check-flow-policies.js <ClipboardFlow.js>");

function load(path) {
    const context = {};
    vm.createContext(context);
    vm.runInContext(fs.readFileSync(path, "utf8").replace(/^\.pragma library\s*$/m, ""), context);
    return context;
}

const clipboard = load(process.argv[2]);
const first = clipboard.rememberTerminal({ id: "op-1", status: "completed" }, {}, 64);
const repeated = clipboard.rememberTerminal({ id: "op-1", status: "completed" }, first.handled, 64);
assert.deepEqual([first.duplicate, repeated.duplicate], [false, true], "handle once, then suppress repeated effects");
console.log("flow policies: duplicate completion suppression passed");
