#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = process.argv[2];
if (!root)
    throw new Error("usage: check-daemon-boundary.js <shelllist-root>");

function source(relative) {
    return fs.readFileSync(path.join(root, relative), "utf8");
}

const transport = source("qml/Shelllist/Io/process/JsonlDaemonClient.qml");
const startFailure = transport.match(/catch \(error\) \{[\s\S]*?Could not start/);
if (!startFailure || !/queuedLines\s*=\s*\[\]/.test(startFailure[0]))
    throw new Error("daemon start failure does not retire queued requests");
const exitHandler = transport.match(/onExited:[\s\S]*?\n\s*\}/);
if (!exitHandler || !/queuedLines\s*=\s*\[\]/.test(exitHandler[0]))
    throw new Error("daemon exit does not retire queued requests");
if (!/environment:\s*\(\{\s*TOKIO_WORKER_THREADS:\s*"1"\s*\}\)/.test(transport))
    throw new Error("daemon bridge clients are not constrained to one Tokio worker");

const backend = source("qml/Shelllist/Io/DaemonBackend.qml");
for (const token of ["required property string expectedProtocol",
        "required property int expectedVersion", "function acceptEvent",
        "ApiEnvelope.compatibilityError", "backend.acceptEvent(event)"]) {
    if (!backend.includes(token))
        throw new Error(`DaemonBackend is missing boundary token: ${token}`);
}

const adapters = [
    "launcher/ApplicationBackend.qml",
    "wifi/WifiBackend.qml",
    "bluetooth/BluetoothBackend.qml",
    "clipboard/ClipboardBackend.qml",
    "bar/BarBackend.qml",
    "activity/ActivityBackend.qml",
    "battery/BatteryBackend.qml",
    "battery/BatteryEnergyBackend.qml"
];
for (const adapter of adapters) {
    const text = source(adapter);
    if (!/expectedProtocol\s*:/.test(text) || !/expectedVersion\s*:/.test(text))
        throw new Error(`${adapter} does not declare its expected API identity`);
}

for (const adapter of ["activity/ActivityBackend.qml", "battery/BatteryBackend.qml"]) {
    if (!/active:\s*controller\.uiActive/.test(source(adapter)))
        throw new Error(`${adapter} keeps a duplicate permanent bar transport`);
}

console.log("daemon boundary checks passed");
