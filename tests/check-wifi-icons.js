#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-wifi-icons.js <WifiIcons.js>");

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, "");
const wifiIcons = {};
vm.createContext(wifiIcons);
vm.runInContext(source, wifiIcons, { filename: helperPath });

let checks = 0;
function expect(label, condition) {
    ++checks;
    if (!condition)
        throw new Error(label);
}

const expectedTypes = [
    ["open", "󰌿"],
    ["enhanced-open", "󱦚"],
    ["legacy", "󰣮"],
    ["personal", "󰌾"],
    ["enterprise", "󰢏"],
    ["unknown", "󰣯"]
];
for (const [securityClass, icon] of expectedTypes) {
    expect(securityClass + " has a dedicated icon",
        wifiIcons.forNetwork({ security_class: securityClass }, false) === icon);
}
expect("captive portal overrides the security icon",
    wifiIcons.forNetwork({ security_class: "open" }, true) === "󱚵");
expect("legacy daemon open networks retain an icon",
    wifiIcons.networkType({ security: "--", flags: 0, wpa_flags: 0, rsn_flags: 0 }, false) === "open");
expect("legacy daemon enterprise flags are classified",
    wifiIcons.networkType({ security: "WPA2/3", flags: 1, rsn_flags: 0x0200 }, false) === "enterprise");
expect("unrecognized secured networks use the unknown icon",
    wifiIcons.networkType({ security: "custom", flags: 1, rsn_flags: 0x4000 }, false) === "unknown");

console.log(`Wi-Fi network icon presentation: ${checks} checks passed`);
