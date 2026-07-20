#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-bluetooth-battery.js <BluetoothBattery.js>");

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, "");
const battery = {};
vm.createContext(battery);
vm.runInContext(source, battery, { filename: helperPath });

let checks = 0;
function expect(label, condition) {
    ++checks;
    if (!condition)
        throw new Error(label);
}

const fastPair = [
    { component: "case", label: "Case", percentage: 78, source: "google-fast-pair-message-stream" },
    { component: "right", label: "Right", percentage: 100, source: "google-fast-pair-message-stream" },
    { component: "left", label: "Left", percentage: 100, source: "google-fast-pair-message-stream" }
];

expect(
    "Fast Pair values have stable component order",
    battery.ordered(fastPair).map(value => value.component).join(",") === "left,right,case"
);
expect(
    "Fast Pair list summary includes every component",
    battery.summary(fastPair) === "L 100% · R 100% · Case 78%"
);
expect(
    "Fast Pair source is identified",
    battery.sourceLabel(fastPair) === "Fast Pair component data"
);

const aggregate = [{ component: "main", label: "Battery", percentage: 64, source: "bluez" }];
expect("aggregate summary remains compact", battery.summary(aggregate) === "64%");
expect("aggregate source is identified", battery.sourceLabel(aggregate) === "BlueZ aggregate data");

const partial = [
    { component: "right", percentage: 55, source: "google-fast-pair-message-stream" },
    { component: "case", percentage: 127, source: "google-fast-pair-message-stream" },
    { component: "left", percentage: -1, source: "google-fast-pair-message-stream" }
];
expect("unknown values are not inferred", battery.summary(partial) === "R 55%");
expect("presentation does not mutate backend order", fastPair[0].component === "case");
expect("missing reports produce no summary", battery.summary(null) === "");

console.log(`Bluetooth battery presentation: ${checks} checks passed`);
