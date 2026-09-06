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

const records = [
    { notification: { id: 3, app_name: "Calendar", group_key: "calendar", hints: {} } },
    { notification: { id: 2, app_name: "Calendar", hints: { desktop_entry: "calendar" } } },
    { notification: { id: 1, app_name: "Chat", hints: { desktop_entry: "chat" } } }
];
const groups = context.groupRecords(records);
equal(groups.length, 2, "records group by group key or desktop entry");
equal(groups[0].records.length, 2, "group retains stack records");
equal(context.groupKey({ app_name: "Fallback", hints: {} }), "Fallback",
    "app name is the grouping fallback");
equal(context.notificationMonitor({ source_monitor: "DP-1" }, "eDP-1", ["eDP-1", "DP-1"]),
    "DP-1", "valid source monitor wins");
equal(context.notificationMonitor({ source_monitor: "missing" }, "eDP-1", ["eDP-1"]),
    "eDP-1", "focused monitor is the route fallback");
equal(context.dndLabel({ dnd: true, dnd_until_unix_ms: 3_600_000 }, 0),
    "DND 1h", "timed DND label");

const active = context.newestFirst([
    { id: 1, created_unix_ms: 100, app_name: "Chat" },
    { id: 2, created_unix_ms: 200, app_name: "Chat" }
]);
equal(active[0].id, 2, "active records are newest first independently of history");
equal(context.filterRecords(records, "Calendar").length, 2, "search filters records before grouping");
equal(context.filterRecords(records, "missing").length, 0, "search has a true empty result");
const merged = context.mergeHistory([
    { history_id: 2, notification: { summary: "old" } }, { history_id: 1 }
], [{ history_id: 3 }, { history_id: 2, notification: { summary: "updated" } }]);
equal(merged.length, 3, "refresh deduplicates without dropping older pages");
equal(merged[0].history_id, 3, "history is newest first");
equal(merged[1].notification.summary, "updated", "incoming records update existing history");
equal(context.groupRecords([{ app_name: "__proto__" }, { app_name: "constructor" }]).length,
    2, "app-controlled group keys cannot collide with object prototypes");
equal(context.relativeTime(60000, 120000), "1m ago", "relative preview time");
equal(context.relativeTime(0, 120000), "", "missing time is not an epoch date");

console.log("notification presentation checks passed");
