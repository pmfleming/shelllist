#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

if (process.argv.length !== 5)
    throw new Error("usage: check-flow-policies.js <ActivityFlow.js> <BatteryFlow.js> <ClipboardFlow.js>");

function load(path) {
    const context = {};
    vm.createContext(context);
    vm.runInContext(fs.readFileSync(path, "utf8").replace(/^\.pragma library\s*$/m, ""), context);
    return context;
}
function equal(actual, expected, message) {
    if (JSON.stringify(actual) !== JSON.stringify(expected))
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}
function ok(value, message) { if (!value) throw new Error(message); }

const activity = load(process.argv[2]);
const selected = new Date(2026, 7, 22);
equal(activity.dateKey(selected), "2026-08-22", "activity date key");
ok(activity.eventOverlapsDate({ start_unix_ms: selected.getTime(), end_unix_ms: selected.getTime() + 1000 }, selected), "timed event overlaps selected date");
ok(activity.todoVisible({ due_date: "2026-08-22" }, "2026-08-22", "2026-08-23"), "dated todo is visible");
equal(activity.eventKind({ event: "changed", stream: "activity" }, { activity: "activity", notifications: "notifications", notificationActive: "active" }), "activity", "activity stream routing");

const battery = load(process.argv[3]);
const batteryState = { policy: { warning_percent: 20 }, devices: [{ id: "BAT0", protection: { supported: true } }] };
const selection = battery.selection(batteryState, 8);
equal(selection.index, 0, "battery selection clamps index");
equal(selection.device.id, "BAT0", "battery selection retains device");
ok(selection.protection.supported, "battery selection carries protection");
const changes = battery.historyChanges({ history: { latest_timestamp_ms: 2, last_charge_timestamp_ms: 3 } }, { latest_timestamp_ms: 1, last_charge_timestamp_ms: 3 });
equal(changes, { history: true, charge: false }, "battery history transition");
equal(battery.energyRequest("week", false, 120000, 100000, 0), null, "fresh energy request is cached");
ok(battery.energyRequest("week", true, 120000, 100000, 0).since < 0, "forced energy request is planned");

const clipboard = load(process.argv[4]);
const running = { id: "op-1", status: "progress" };
ok(clipboard.operationRunning(running), "clipboard progress is active");
const first = clipboard.rememberTerminal({ id: "op-1", status: "completed" }, {}, 64);
ok(!first.duplicate && first.handled["op-1"], "clipboard terminal operation is remembered");
ok(clipboard.rememberTerminal({ id: "op-1", status: "completed" }, first.handled, 64).duplicate, "clipboard duplicate terminal operation is rejected");
const detailed = clipboard.detailedEntry({ id: "old", revision: 1 }, { entry: { id: "new", revision: 2 } }, ["old"]);
equal(detailed.id, "new", "clipboard replacement detail is preferred");

console.log("flow policies: 14 checks passed");
