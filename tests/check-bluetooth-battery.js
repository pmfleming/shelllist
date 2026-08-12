#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-bluetooth-battery.js <BluetoothBattery.js> [bluetooth-root]");
const bluetoothRoot = process.argv[3] || path.dirname(helperPath);

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

function expectDeviceImage(label, device, expected) {
    const image = battery.imageFor(device, { component: "main" });
    expect(label + " selects its artwork", image === expected);
    expect(label + " artwork exists", fs.existsSync(path.resolve(bluetoothRoot, image)));
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
    "Fast Pair visual layout places the case between the earbuds",
    battery.visualOrdered(fastPair).map(value => value.component).join(",") === "left,case,right"
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
expect("component artwork is selected centrally", battery.imageFor({}, fastPair[0]).endsWith("charging-case.png"));
expectDeviceImage("known earbuds despite a transient headphone icon", {
    device_type: "Earbuds", icon: "audio-headphones"
}, "assets/audio/left-earbud.png");
expectDeviceImage("known headphones despite a transient headset icon", {
    device_type: "Headphones", icon: "audio-headset"
}, "assets/audio/headphones.png");
expectDeviceImage("known types without dedicated artwork despite a contradictory icon", {
    device_type: "Tablet", icon: "audio-headphones"
}, "assets/devices/unknown-device.png");
expectDeviceImage("computer", { icon: "computer" }, "assets/devices/computer.png");
expectDeviceImage("game controller", { icon: "input-gaming" }, "assets/devices/game-controller.png");
expectDeviceImage("keyboard", { icon: "input-keyboard" }, "assets/devices/keyboard.png");
expectDeviceImage("mouse", { icon: "input-mouse" }, "assets/devices/mouse.png");
expectDeviceImage("phone", { icon: "phone" }, "assets/devices/phone.png");
expectDeviceImage("speaker", { icon: "audio-speakers" }, "assets/devices/speaker.png");
expectDeviceImage("unknown device", { icon: "" }, "assets/devices/unknown-device.png");
expectDeviceImage("audio service fallback", { services: [{ label: "Audio Sink" }] }, "assets/audio/headphones.png");

const remembered = battery.enrichDevices([{ key: "headset", connected: false, battery: [] }], { headset: aggregate });
expect("disconnected devices restore remembered reports", remembered.devices[0].battery[0].percentage === 64);
expect("restored reports are marked last-known", remembered.devices[0].battery_last_known === true);
const connected = battery.enrichDevices([{ key: "headset", connected: true, battery: [] }], remembered.cache);
expect("connected devices hide stale reports without dropping the cache",
    connected.devices[0].battery.length === 0 && connected.cache.headset[0].percentage === 64);
expect("devices absent from a snapshot are pruned", Object.keys(battery.enrichDevices([], connected.cache).cache).length === 0);

console.log(`Bluetooth battery presentation: ${checks} checks passed`);
