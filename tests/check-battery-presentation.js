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
equal(context.sleepHandlerName("NetworkManager"), "Network", "friendly network name");
equal(context.sleepHandlerName("ModemManager"), "Mobile broadband", "friendly modem name");
equal(context.sleepHandlerName("net.reactivated.Fprint"), "Fingerprint reader", "friendly fingerprint name");
equal(context.sleepHandlerName("Editor"), "Editor", "unknown application names are preserved");
equal(context.sleepCapabilityDescription(sleep, "hibernate"), "Not supported by the system", "unsupported does not invent a swap diagnosis");
equal(context.sleepCapabilityDescription({ ...sleep, can_hibernate: "no" }, "hibernate"), "Not permitted by system policy", "permission denial explained");
equal(context.sleepCapabilityDescription({ ...sleep, can_hibernate: "challenge" }, "hibernate"), "Authorisation required · locks before sleeping", "authentication requirement explained");
equal(context.sleepCapabilityDescription({ ...sleep, available: false }, "suspend"), "Sleep service unavailable", "offline state overrides stale capabilities");
console.log("battery presentation: policy validation, sleep filtering and capability explanations passed");
