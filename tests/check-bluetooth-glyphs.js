#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const helperPath = process.argv[2];
if (!helperPath)
    throw new Error("usage: check-bluetooth-glyphs.js <BluetoothGlyphs.js>");

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, "");
const glyphs = {};
vm.createContext(glyphs);
vm.runInContext(source, glyphs, { filename: helperPath });

let checks = 0;
function expect(label, condition) {
    ++checks;
    if (!condition)
        throw new Error(label);
}

const earbuds = {
    icon: "audio-headset",
    battery: [
        { component: "left", percentage: 90 },
        { component: "right", percentage: 85 },
        { component: "case", percentage: 70 }
    ]
};
expect("component data classifies untethered earbuds", glyphs.forDevice(earbuds) === "󱡏");
expect("left bud uses earbud glyph", glyphs.forBattery(earbuds.battery[0]) === "󱡏");
expect("right bud uses earbud glyph", glyphs.forBattery(earbuds.battery[1]) === "󱡏");
expect("case uses charging-case glyph", glyphs.forBattery(earbuds.battery[2]) === "󰋌");
expect("aggregate battery uses battery glyph", glyphs.forBattery({ component: "main" }) === "󰁹");

expect("headphones use generic headphones", glyphs.forDevice({ icon: "audio-headphones" }) === "󰋋");
expect("headsets use generic headset", glyphs.forDevice({ icon: "audio-headset" }) === "󰋎");
expect("speakers use generic speaker", glyphs.forDevice({ icon: "audio-speakers" }) === "󰓃");
expect("keyboards use generic keyboard", glyphs.forDevice({ icon: "input-keyboard" }) === "󰌌");
expect("mice use generic mouse", glyphs.forDevice({ icon: "input-mouse" }) === "󰍽");
expect("controllers use generic controller", glyphs.forDevice({ icon: "input-gaming" }) === "󰊴");
expect("audio service fallback remains generic", glyphs.forDevice({ services: [{ label: "Audio Sink" }] }) === "󰥰");
expect("unknown devices use Bluetooth glyph", glyphs.forDevice({ icon: "" }) === "󰂯");

console.log(`Bluetooth glyph presentation: ${checks} checks passed`);
