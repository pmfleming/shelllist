#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");
const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-wifi-qr.js <WifiQr.js>");

const qr = {};
vm.createContext(qr);
vm.runInContext(fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, ""), qr);

function expect(label, actual, expected) {
    if (actual !== expected)
        throw new Error(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

const payload = "WIFI:T:WPA;S:Cafe\\;Guest;P:pa\\;ss\\\\word;;";
expect("escaped SSID", qr.payloadField(payload, "S"), "Cafe;Guest");
expect("escaped password", qr.payloadField(payload, "P"), "pa;ss\\word");
expect("missing field", qr.payloadField(payload, "H"), "");
console.log("Wi-Fi QR payload parsing checks passed");
