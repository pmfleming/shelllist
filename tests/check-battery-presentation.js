#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const vm = require("vm");

let source = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, "");
const durationImport = source.match(/^\.import\s+"([^"]+)"\s+as\s+Duration\s*$/m);
const Duration = {};
vm.createContext(Duration);
vm.runInContext(fs.readFileSync(process.argv[3]
    || path.resolve(path.dirname(process.argv[2]), durationImport[1]), "utf8")
    .replace(/^\.pragma library\s*$/m, ""), Duration);
const context = { Duration };
vm.createContext(context);
vm.runInContext(source.replace(durationImport[0], ""), context);
function equal(actual, expected, message) {
    if (actual !== expected)
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

// Controller saves exercise valid ranges; retain the invalid boundaries here.
equal(context.thresholdRangeValid(80, 80), false, "equal thresholds rejected");
equal(context.alertRangeValid(10, 12), false, "critical above warning rejected");
const suspend = { available: true, can_suspend: "yes", can_hibernate: "na", inhibitors: [
    { what: "sleep", mode: "delay", who: "NetworkManager", why: "Disconnecting" },
    { what: "shutdown:sleep", mode: "block", who: "Editor", why: "Saving" },
    { what: "sleep", mode: "block-weak", who: "Recorder", why: "Recording" },
    { what: "shutdown", mode: "block", who: "Updater" },
    { what: "handle-lid-switch", mode: "block", who: "Desktop" },
    { what: "idle", mode: "delay", who: "Player" }
] };
equal(context.suspendInhibitors(suspend, "block").length, 2, "only suspend blockers are relevant");
// BatterySuspend owns visible status and capability messages; BatteryController
// owns dispatch rejection. Only diagnosis precedence needs a separate oracle.
const diagnosed = { ...suspend, diagnostics: { hibernate_issues: ["No active disk-backed swap; zram alone cannot store a hibernation image."] } };
equal(context.suspendCapabilityDescription(diagnosed, "hibernate"), diagnosed.diagnostics.hibernate_issues[0], "daemon evidence explains the unavailable hibernate action");
equal(context.suspendCapabilityDescription({ ...diagnosed, can_hibernate: "no" }, "hibernate"), "Disabled or not permitted by system policy", "hardware evidence does not mislabel policy denial");
for (const unknown of [undefined, "other", "constructor", "toString", "__proto__"]) {
    equal(context.automationStatus({ status: unknown }, true), "Automatic switching status unavailable", "unknown automation token");
    equal(context.suspendCapabilityDescription({ available: true, can_suspend: unknown }, "suspend"), "Capability unavailable", "unknown capability token");
}
for (const token of ["inhibited", "inhibitor-blocked"]) equal(context.suspendCapabilityDescription({ available: true, can_suspend: token }, "suspend"), "Temporarily blocked by an application’s suspend inhibitor", token);
equal(context.automationStatus({ status: "active", level: "critical", profile: "power-saver" }, true), "Critical battery · requesting Power saver", "active automation");
equal(context.automationStatus({ status: "error" }, true), "Automatic switching failed · Unknown error", "missing error detail");
equal(context.suspendCapabilityDescription({ ...diagnosed, keep_awake: true }, "hibernate"), "Turn off Keep awake before hibernating", "keep-awake precedence");
equal(context.suspendCapabilityDescription({ ...diagnosed, keep_awake: true }, "lock"), "Lock the current session", "lock bypasses keep-awake");
console.log("battery presentation: policy validation, suspend filtering and capability explanations passed");
