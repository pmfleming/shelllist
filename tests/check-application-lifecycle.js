#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");
const assert = require("node:assert/strict");
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, ""), context);

// Each rejected boundary keeps its own diagnostic, without repetitive helpers.
const request = { actionId: "focus-window-2" };
for (const [label, actual, expected] of [
    ["unsafe daemon revision", context.expectedRevision(15592525670148626000), null],
    ["another target", context.operationMatches(request, "app.desktop", {target_id: "other.desktop", action: "focus-window"}), false],
    ["unmatched acceptance", context.operationTransition(request, "app.desktop", "", "action-1", {id: "operation-1", status: "accepted"}), null],
    ["another operation", context.operationTransition(request, "app.desktop", "operation-1", "", {id: "operation-2", status: "running"}), null]
])
    assert.equal(actual, expected, label);
console.log("application lifecycle: safe revisions and asynchronous operation isolation passed");
