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

equal(context.thresholdRangeValid(75, 80), true, "valid threshold range");
equal(context.thresholdRangeValid(80, 80), false, "equal thresholds rejected");
equal(context.alertRangeValid(25, 12), true, "valid alert range");
equal(context.alertRangeValid(10, 12), false, "critical above warning rejected");
const sleep = { available: true, can_suspend: "yes", can_hibernate: "na", inhibitors: [
    { what: "sleep", mode: "delay", who: "NetworkManager", why: "Disconnecting" },
    { what: "shutdown:sleep", mode: "block", who: "Editor", why: "Saving" },
    { what: "sleep", mode: "block-weak", who: "Recorder", why: "Recording" },
    { what: "shutdown", mode: "block", who: "Updater" },
    { what: "handle-lid-switch", mode: "block", who: "Desktop" },
    { what: "idle", mode: "delay", who: "Player" }
] };
equal(context.sleepInhibitors(sleep, "block").length, 2, "only sleep blockers are relevant");
equal(context.sleepInhibitors(sleep, "delay").length, 1, "normal handlers are separated");
equal(context.sleepStatus(sleep, "", "", ""), "Sleep blocked", "real blockers surface a concise warning");
equal(context.sleepStatus({ ...sleep, inhibitors: [sleep.inhibitors[0]] }, "", "", ""), "", "routine handlers are not warnings");
equal(context.sleepCapabilityDescription(sleep, "hibernate"), "Not supported by the system", "unsupported does not invent a swap diagnosis");
equal(context.sleepCapabilityDescription({ ...sleep, can_hibernate: "no" }, "hibernate"), "Not permitted by system policy", "permission denial explained");
equal(context.sleepCapabilityDescription({ ...sleep, can_hibernate: "challenge" }, "hibernate"), "Authorisation required · locks before sleeping", "authentication requirement explained");
equal(context.sleepCapabilityDescription({ ...sleep, available: false }, "suspend"), "Sleep service unavailable", "offline state overrides stale capabilities");
equal(context.sleepCapabilityDescription({ ...sleep, keep_awake: true }, "suspend"), "Turn off Keep awake before sleeping", "inhibition explains disabled sleep");
equal(context.sleepCapabilityDescription({ ...sleep, keep_awake: true }, "lock"), "Lock the current session", "locking is unaffected");
equal(context.sleepStatus({ ...sleep, keep_awake: true }, "", "", ""), "Keep awake on · sleep & hibernate blocked", "own inhibitor has actionable status");
equal(context.sleepStatus({ ...sleep, keep_awake: true, available: false }, "", "", ""), "Sleep controls unavailable", "stale inhibition is not claimed active");
const diagnosed = { ...sleep, diagnostics: { hibernate_issues: ["No active disk-backed swap; zram alone cannot store a hibernation image."] } };
equal(context.sleepCapabilityDescription(diagnosed, "hibernate"), diagnosed.diagnostics.hibernate_issues[0], "daemon evidence explains the unavailable hibernate action");
equal(context.sleepCapabilityDescription({ ...diagnosed, can_hibernate: "no" }, "hibernate"), "Not permitted by system policy", "hardware evidence does not mislabel policy denial");
console.log("battery presentation: policy validation, sleep filtering and capability explanations passed");
