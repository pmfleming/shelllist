#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");
const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-wifi-icons.js <WifiIcons.js>");
const icons = {};
vm.createContext(icons);
vm.runInContext(fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, ""), icons);
function expect(label, condition) {
    if (!condition) throw new Error(label);
}
expect("captive portal takes precedence over security class",
    icons.networkType({ security_class: "enterprise" }, true) === "captive-portal");
expect("open and enterprise networks remain visually distinguishable",
    icons.forNetwork({ security_class: "open" }, false)
        !== icons.forNetwork({ security_class: "enterprise" }, false));
console.log("Wi-Fi presentation: security distinctions and captive portal precedence passed");
