#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");
const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-bluetooth-battery.js <BluetoothBattery.js>");
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
expect("unknown components do not invent percentages",
    reports.filter(value => battery.isValid(value)).map(value => value.component).join(",") === "right");
expect("unknown values are not inferred", battery.summary([
    { component: "right", percentage: 55 }, { component: "case", percentage: 127 },
    { component: "left", percentage: -1 }
]) === "R 55%");
console.log("Bluetooth battery: component telemetry and unknown values passed");
