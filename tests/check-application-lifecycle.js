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
equal(context.expectedRevision(9007199254740991), 9007199254740991,
    "largest JavaScript-safe revision is retained");
equal(context.expectedRevision(42), 42, "ordinary revision is retained");
equal(context.expectedRevision(null), null, "missing revision remains absent");

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

equal(context.operationTransition(request, "app.desktop", "", "action-1", {
    id: "operation-1", status: "accepted"
}), null, "accepted response must match the active request");
const accepted = context.operationTransition({ id: "action-1", actionId: "focus-window-2" },
    "app.desktop", "", "action-1", { id: "operation-1", status: "accepted" });
equal(accepted.stage, "active", "accepted operation remains active");
equal(accepted.operationId, "operation-1", "accepted operation captures its daemon id");
const completed = context.operationTransition(request, "app.desktop", "", "", {
    id: "operation-1", status: "completed", target_id: "app.desktop", action: "focus-window"
});
equal(completed.stage, "terminal", "matching completion is terminal");
equal(context.operationTransition(request, "app.desktop", "operation-1", "", {
    id: "operation-2", status: "running"
}), null, "events from another operation are rejected");

console.log("application lifecycle: 16 checks passed");
