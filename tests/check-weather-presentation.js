#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const context = { Date, Number, Math, String };
vm.createContext(context);
vm.runInContext(source, context);

function equal(actual, expected, message) {
    if (actual !== expected)
        throw new Error(`${message}: expected ${expected}, got ${actual}`);
}

equal(context.iconName(0, true), "clear-day", "clear day artwork");
equal(context.iconName(0, false), "clear-night", "clear night artwork");
equal(context.iconName(63, true), "rain", "rain artwork");
equal(context.iconName(75, false), "snow", "snow artwork");
equal(context.iconName(95, false), "thunderstorms-night", "night storm artwork");
equal(context.localTime(0, -5 * 3600), "19:00", "negative location offset");
equal(context.localTime(0, 5.5 * 3600), "05:30", "fractional location offset");
equal(context.windCompass(315), "NW", "wind direction");
equal(context.windCompass(359), "N", "wrapped wind direction");

console.log("weather presentation: artwork, local times, and wind direction passed");
