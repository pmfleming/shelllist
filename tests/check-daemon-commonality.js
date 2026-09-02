#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = process.argv[2];
if (!root)
    throw new Error("usage: check-daemon-commonality.js <shelllist-root>");

function source(relative) {
    return fs.readFileSync(path.join(root, relative), "utf8");
}

const commonBackend = source("qml/Shelllist/Io/DaemonBackend.qml");
for (const token of ["function nextRequestId", "function callSequenced",
        "function responseError", "function eventEnvelopeError", "function routeEvent"]) {
    if (!commonBackend.includes(token))
        throw new Error(`DaemonBackend is missing common primitive: ${token}`);
}

const domains = [
    { api: "launcher/AppApi.js", backend: "launcher/ApplicationBackend.qml", alias: "AppApi" },
    { api: "wifi/NmApi.js", backend: "wifi/WifiBackend.qml", alias: "NmApi" },
    { api: "bluetooth/BtApi.js", backend: "bluetooth/BluetoothBackend.qml", alias: "BtApi" },
    { api: "clipboard/ClipApi.js", backend: "clipboard/ClipboardBackend.qml", alias: "ClipApi" },
    { api: "bar/BarApi.js", backend: "bar/BarBackend.qml", alias: "BarApi" }
];

for (const domain of domains) {
    const api = source(domain.api);
    const backend = source(domain.backend);
    for (const declaration of ["var protocol", "var version", "var methods", "var streams",
            "var subscribedStreams"]) {
        if (!api.includes(declaration))
            throw new Error(`${domain.api} is missing the common API member: ${declaration}`);
    }
    for (const binding of [`expectedProtocol: ${domain.alias}.protocol`,
            `expectedVersion: ${domain.alias}.version`, `streams: ${domain.alias}.subscribedStreams`]) {
        if (!backend.includes(binding))
            throw new Error(`${domain.backend} is missing common endpoint binding: ${binding}`);
    }
}

const migratedBackends = [
    "launcher/ApplicationBackend.qml",
    "bluetooth/BluetoothBackend.qml",
    "clipboard/ClipboardBackend.qml",
    "bar/BarBackend.qml",
    "activity/ActivityBackend.qml",
    "battery/BatteryBackend.qml",
    "battery/BatteryEnergyBackend.qml",
    "qml/Shelllist/Io/ClipboardPublisher.qml",
    "qml/Shelllist/Io/ClipboardScreenshotCapture.qml"
];
for (const file of migratedBackends) {
    const text = source(file);
    if (text.includes("Core.ApiEnvelope.responseError"))
        throw new Error(`${file} bypasses DaemonBackend.responseError`);
    if (/property int (?:operationS|s)equence\b/.test(text))
        throw new Error(`${file} owns a duplicate request sequence`);
}

for (const file of ["wifi/WifiController.qml", "activity/ActivityController.qml",
        "battery/BatteryController.qml", "bar/BarController.qml"]) {
    if (source(file).includes("compatibilityError"))
        throw new Error(`${file} duplicates transport-level event validation`);
}
if (source("wifi/NmApiClient.js").includes("requireApiEvent"))
    throw new Error("NmApiClient duplicates transport-level event validation");

console.log("daemon commonality checks passed");
