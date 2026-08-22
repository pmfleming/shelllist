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

console.log("notification presentation checks passed");
