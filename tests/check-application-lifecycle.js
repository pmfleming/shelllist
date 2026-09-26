#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

function equal(actual, expected, message) {
    if (actual !== expected)
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

equal(context.expectedRevision(15592525670148626000), null,
    "unsafe daemon revision disables stale-state validation");

const request = { actionId: "focus-window-2" };
equal(context.operationMatches(request, "app.desktop", {
    target_id: "other.desktop", action: "focus-window"
}), false, "another target is rejected");

equal(context.operationTransition(request, "app.desktop", "", "action-1", {
    id: "operation-1", status: "accepted"
}), null, "accepted response must match the active request");
equal(context.operationTransition(request, "app.desktop", "operation-1", "", {
    id: "operation-2", status: "running"
}), null, "events from another operation are rejected");

console.log("application lifecycle: safe revisions and asynchronous operation isolation passed");
