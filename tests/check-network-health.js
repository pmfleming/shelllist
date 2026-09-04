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

const daemonFailure = event({
    subject: "device", state_name: "failed", unexpected: true, user_requested: false,
    transition_kind: "failure", notification_recommended: true, severity: "error",
    message: "Example failed to authenticate.", device_path: "/devices/1",
    reason: { code: 7, name: "no-secrets", category: "authentication" }, id: "Example"
});
expect("daemon recommended failure is surfaced", health.isFailure(daemonFailure), true);
expect("daemon message is preferred", health.message(daemonFailure), "Example failed to authenticate.");
expect("notification key is stable", health.notificationKey(daemonFailure), "/devices/1|failed|no-secrets");
expect("duplicate notification is suppressed", health.isDuplicateNotification(
    daemonFailure, "/devices/1|failed|no-secrets", 1000, 2000, 3000), true);

const daemonSuppressed = event({
    subject: "connection", state_name: "deactivated", unexpected: true, user_requested: false,
    transition_kind: "failure", notification_recommended: false, severity: "warning",
    reason: { code: 3, name: "device-disconnected", category: "dependency" }, id: "Example"
});
expect("daemon suppressed failure stays quiet", health.isFailure(daemonSuppressed), false);

const inconsistentProgress = event({
    subject: "device", state_name: "failed", unexpected: true, user_requested: false,
    transition_kind: "progress", notification_recommended: true,
    reason: { code: 17, name: "dhcp-failed", category: "address-assignment" }
});
expect("non-failure transition kind stays quiet", health.isFailure(inconsistentProgress), false);

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

const successfulActivationTrace = [
    { subject: "connection", state_name: "activating", transition_kind: "progress" },
    { subject: "device", state_name: "prepare", transition_kind: "progress" },
    { subject: "device", state_name: "config", transition_kind: "progress" },
    { subject: "device", state_name: "ip-config", transition_kind: "progress" },
    { subject: "device", state_name: "activated", transition_kind: "success" },
    { subject: "connection", state_name: "activated", transition_kind: "success" }
].map(detail => event(Object.assign(detail, {
    unexpected: false, user_requested: false, notification_recommended: false,
    reason: { code: 0, name: "unknown", category: "unknown" }
})));
expect("successful activation trace is quiet",
    successfulActivationTrace.some(health.isFailure), false);

const sleepTrace = [
    { subject: "device", state_name: "deactivating", reason: "sleeping" },
    { subject: "connection", state_name: "deactivating", reason: "unknown" },
    { subject: "device", state_name: "disconnected", reason: "sleeping" },
    { subject: "device", state_name: "unmanaged", reason: "unmanaged-sleeping" }
].map(item => event({
    subject: item.subject, state_name: item.state_name, transition_kind: "expected-lifecycle",
    unexpected: false, user_requested: false, notification_recommended: false,
    reason: { code: 37, name: item.reason, category: "lifecycle" }
}));
expect("sleep trace is quiet", sleepTrace.some(health.isFailure), false);

for (const [label, detail] of [
    ["DHCP failure", { subject: "device", state_name: "failed", reason: "ip-config-unavailable", category: "address-assignment" }],
    ["authentication failure", { subject: "device", state_name: "failed", reason: "no-secrets", category: "authentication" }],
    ["link loss", { subject: "device", state_name: "disconnected", reason: "supplicant-disconnect", category: "authentication" }],
    ["unknown VPN failure", { subject: "vpn", state_name: "failed", reason: "unknown", category: "unknown" }]
]) {
    const failure = event({
        subject: detail.subject, state_name: detail.state_name, transition_kind: "failure",
        unexpected: true, user_requested: false, notification_recommended: true,
        reason: { code: 1, name: detail.reason, category: detail.category }
    });
    expect(label + " remains actionable", health.isFailure(failure), true);
}

expect("log line has no secret field", health.logLine(authFailure).indexOf("password") >= 0, false);
expect("log line reports reason", health.logLine(authFailure).indexOf("reason=no-secrets") >= 0, true);

console.log("network health presentation checks passed");
