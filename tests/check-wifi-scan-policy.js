#!/usr/bin/env node
const fs = require("fs");

if (process.argv.length !== 4)
    throw new Error("usage: check-wifi-scan-policy.js <WifiScanController.qml> <WifiBackend.qml>");

const controller = fs.readFileSync(process.argv[2], "utf8");
const backend = fs.readFileSync(process.argv[3], "utf8");
function ok(value, message) { if (!value) throw new Error(message); }

ok(controller.includes("function activate() { warmCache(); }"), "UI activation must warm the freshness-aware cache");
ok(controller.includes("backend.refreshNetworks(true)"), "cache warmup must request a freshness-aware background refresh");
ok(!controller.includes("refreshTimer"), "Wi-Fi UI must not own a repeating refresh timer");
ok(!controller.includes("repeat: true"), "Wi-Fi scan controller must not contain a repeating timer");
ok(controller.includes("interval: 25000"), "watchdog must leave margin beyond the daemon timeout");
ok(controller.includes("refresh manually to retry"), "watchdog failure must require an explicit retry");
ok(backend.includes("timeout: 20, cache: true"), "explicit scan timeout must cover rate-limit and scan work");
ok(backend.includes("snapshot.refresh_requested"), "UI must render the daemon's refresh disposition");

console.log("wifi scan policy: 8 checks passed");
