#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8")
    .replace(/^\.pragma library\s*$/m, "")
    .replace(/if \(typeof module[\s\S]*$/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

function equal(actual, expected, message) {
    if (actual !== expected)
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

equal(context.expectedOperationAction("focus-window-2"), "focus-window", "focus action maps");
equal(context.expectedOperationAction("close-window-3"), "close-window", "close action maps");
equal(context.expectedOperationAction("desktop-action-1"), "desktop-action", "desktop action maps");
equal(context.expectedOperationAction("activate"), "activate", "base action remains stable");

const request = { actionId: "focus-window-2" };
equal(context.operationMatches(request, "app.desktop", {
    target_id: "app.desktop", action: "focus-window"
}), true, "matching asynchronous operation is accepted");
equal(context.operationMatches(request, "app.desktop", {
    target_id: "other.desktop", action: "focus-window"
}), false, "another target is rejected");
equal(context.operationMatches(request, "app.desktop", {
    target_id: "app.desktop", action: "activate"
}), false, "another action is rejected");

equal(context.isActiveStatus("accepted"), true, "accepted is active");
equal(context.isActiveStatus("running"), true, "running is active");
equal(context.isTerminalStatus("completed"), true, "completed is terminal");
equal(context.isTerminalStatus("failed"), true, "failed is terminal");
equal(context.isTerminalStatus("cancelled"), true, "cancelled is terminal");

console.log("application lifecycle: 12 checks passed");
