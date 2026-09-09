#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-bluetooth-battery.js <BluetoothBattery.js> [bluetooth-root]");
const bluetoothRoot = process.argv[3] || path.dirname(helperPath);
const battery = {};
vm.createContext(battery);
vm.runInContext(fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, ""), battery);
function expect(label, condition) {
    if (!condition) throw new Error(label);
}

const reports = battery.displayReports({
    device_type: "Earbuds", components: ["left", "right", "case"],
    battery: [{ component: "right", percentage: 55, source: "test" }]
});
expect("reported topology survives partial telemetry", reports.length === 3);
expect("unknown components do not invent percentages",
    reports.filter(value => battery.isValid(value)).map(value => value.component).join(",") === "right");
expect("unknown values are not inferred", battery.summary([
    { component: "right", percentage: 55 }, { component: "case", percentage: 127 },
    { component: "left", percentage: -1 }
]) === "R 55%");
// Metadata priority is a regression boundary; the full asset/type lookup table is not.
const known = { device_type: "Earbuds", icon: "audio-headphones" };
const knownImage = battery.imageFor(known, { component: "main" });
expect("known type wins over a transient icon",
    knownImage === battery.imageFor({ device_type: "Earbuds" }, { component: "main" })
        && knownImage !== battery.imageFor({ device_type: "Headphones" }, { component: "main" }));
for (const device of [known, { icon: "unknown" }])
    expect("selected artwork exists", fs.existsSync(path.resolve(bluetoothRoot,
        battery.imageFor(device, { component: "main" }))));
console.log("Bluetooth battery: component telemetry, unknown values and metadata priority passed");
