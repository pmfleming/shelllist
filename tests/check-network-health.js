#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");
const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-network-health.js <NetworkHealth.js>");

const health = {};
vm.createContext(health);
vm.runInContext(fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, ""), health);

function expect(label, actual, expected) {
    if (actual !== expected)
        throw new Error(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

function event(detail) {
    return { stream: "network.health", event: detail.subject, health: detail };
}

const authFailure = event({
    subject: "device", state_name: "failed", unexpected: true, user_requested: false,
    reason: { code: 7, name: "no-secrets", category: "authentication" },
    id: "Example", device_iface: "wlan0"
});
expect("auth failure is a failure", health.isFailure(authFailure), true);
expect("auth failure message", health.message(authFailure), "Example needs a password.");

const userDisconnect = event({
    subject: "connection", state_name: "deactivated", unexpected: false, user_requested: true,
    reason: { code: 2, name: "user-disconnected", category: "user-requested" },
    id: "Example"
});
expect("user disconnect is quiet", health.isQuiet(userDisconnect), true);
expect("user disconnect is not a failure", health.isFailure(userDisconnect), false);

const lifecycle = event({
    subject: "device", state_name: "unmanaged", unexpected: true, user_requested: false,
    reason: { code: 73, name: "unmanaged-sleeping", category: "lifecycle" },
    device_iface: "wlan0"
});
expect("lifecycle transitions stay quiet", health.isFailure(lifecycle), false);

const unknownReason = event({
    subject: "vpn", state_name: "failed", unexpected: true, user_requested: false,
    reason: { code: 9999, name: "unknown", category: "unknown" },
    id: "Work VPN"
});
expect("unknown reason still reports", health.isFailure(unknownReason), true);
expect("unknown reason message", health.message(unknownReason), "VPN Work VPN is failed.");

const progress = event({
    subject: "device", state_name: "ip-config", unexpected: true, user_requested: false,
    reason: { code: 0, name: "none", category: "none" }, device_iface: "wlan0"
});
expect("ordinary progress is quiet", health.isFailure(progress), false);

expect("log line has no secret field", health.logLine(authFailure).indexOf("password") >= 0, false);
expect("log line reports reason", health.logLine(authFailure).indexOf("reason=no-secrets") >= 0, true);

console.log("network health presentation checks passed");
