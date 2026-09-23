#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8")
    .replace(/^\.pragma\s+library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context, { filename: process.argv[2] });

function equal(actual, expected, label) {
    if (actual !== expected)
        throw new Error(`${label}: expected ${expected}, got ${actual}`);
}

// Filtering, history catch-up, DND and preview reachability are exercised by
// the real QML consumers. Keep routing and adversarial identity cases here.
equal(context.notificationMonitor({ source_monitor: "DP-1" }, "eDP-1", ["eDP-1", "DP-1"]),
    "DP-1", "valid source monitor wins");
equal(context.notificationMonitor({ source_monitor: "missing" }, "eDP-1", ["eDP-1"]),
    "eDP-1", "focused monitor is the route fallback");
const merged = context.mergeHistory([
    { history_id: 2, notification: { summary: "old" } }, { history_id: 1 }
], [{ history_id: 3 }, { history_id: 2, notification: { summary: "updated" } }]);
equal(merged.find(record => record.history_id === 2).notification.summary,
    "updated", "incoming records update existing history");
equal(context.groupRecords([{ app_name: "__proto__" }, { app_name: "constructor" }]).length,
    2, "app-controlled group keys cannot collide with object prototypes");

const recent = context.recentRecords([
    { id: 2, created_unix_ms: 200, summary: "live" }
], [
    { history_id: 3, notification: { id: 3, created_unix_ms: 300 } },
    { history_id: 2, notification: { id: 2, created_unix_ms: 200 } },
    { history_id: 1, notification: { id: 2, created_unix_ms: 100 } }
]);
equal(recent[1].summary, "live", "active snapshot wins over its history copy");
equal(recent[2].history_id, 1, "reusing a notification ID does not erase older history");
console.log("notification presentation: monitor routing, updates and identity isolation passed");
