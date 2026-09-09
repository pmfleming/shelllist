#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, ""), context);
function equal(actual, expected, message) {
    if (actual !== expected)
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

const retained = context.withoutClosedInstances({
    instances: [{ id: "one", focused: true }, { id: "two", focused: false }]
}, "close-window-1", "one");
equal(retained.running_count, 1, "closed window count");
equal(retained.focused, false, "closed focused window state");
console.log("application presentation: closed-window state passed");
