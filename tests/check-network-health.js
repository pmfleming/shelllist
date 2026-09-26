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

const daemonFailure = event({
    subject: "device", state_name: "failed", unexpected: true, user_requested: false,
    transition_kind: "failure", notification_recommended: true, severity: "error",
    message: "Example failed to authenticate.", device_path: "/devices/1",
    reason: { code: 7, name: "no-secrets", category: "authentication" }, id: "Example"
});
expect("daemon recommended failure is surfaced", health.isFailure(daemonFailure), true);
expect("duplicate notification is suppressed", health.isDuplicateNotification(
    daemonFailure, health.notificationKey(daemonFailure), 1000, 2000, 3000), true);

const daemonSuppressed = event({
    subject: "connection", state_name: "deactivated", unexpected: true, user_requested: false,
    transition_kind: "failure", notification_recommended: false, severity: "warning",
    reason: { code: 3, name: "device-disconnected", category: "dependency" }, id: "Example"
});
expect("daemon suppressed failure stays quiet", health.isFailure(daemonSuppressed), false);

expect("non-boolean advice is not interpreted as approval", health.isFailure(event({
    notification_recommended: "true"
})), false);

// The daemon classifies lifecycle traces. Repeating each reason/state here
// only retests the recommendation boolean, not DHCP, VPN or suspend behavior.

const secret = "must-not-appear-in-health-logs";
const withSecret = event({ ...daemonFailure.health, password: secret, secrets: { psk: secret } });
expect("log line omits credential fields", health.logLine(withSecret).includes(secret), false);

console.log("network health presentation checks passed");
