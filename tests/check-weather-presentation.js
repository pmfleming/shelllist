#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const timezoneMap = fs.readFileSync(process.argv[3], "utf8");
const timezoneAsset = fs.readFileSync(process.argv[4], "utf8");
const context = { Date, Number, Math, String };
vm.createContext(context);
vm.runInContext(source, context);

function equal(actual, expected, message) {
    if (actual !== expected)
        throw new Error(`${message}: expected ${expected}, got ${actual}`);
}

function assert(condition, message) {
    if (!condition)
        throw new Error(message);
}

function timezoneBandColor(offset) {
    const match = timezoneAsset.match(new RegExp("\\.w" + offset
        + "\\s*\\{fill:(#[0-9A-Fa-f]{6})"));
    assert(match, `missing timezone band color for UTC${offset}`);
    return match[1].slice(1).match(/../g).map(value => parseInt(value, 16));
}

function colorDistance(left, right) {
    return Math.sqrt(left.reduce((sum, value, index) =>
        sum + Math.pow(value - right[index], 2), 0));
}

equal(context.iconName(0, true), "clear-day", "clear day artwork");
equal(context.iconName(0, false), "clear-night", "clear night artwork");
equal(context.iconName(63, true), "rain", "rain artwork");
equal(context.iconName(75, false), "snow", "snow artwork");
equal(context.iconName(95, false), "thunderstorms-night", "night storm artwork");
equal(context.localTime(0, -5 * 3600), "19:00", "negative location offset");
equal(context.localTime(0, 5.5 * 3600), "05:30", "fractional location offset");
equal(context.utcOffset(-5 * 3600), "UTC−5", "negative UTC offset");
equal(context.utcOffset(5.5 * 3600), "UTC+5:30", "fractional UTC offset");
equal(context.duration(13 * 3600 + 32 * 60), "13 h 32 min", "day length");
equal(context.moonPhase(Date.UTC(2000, 0, 6, 18, 14)).name,
    "New moon", "known new moon");
equal(context.windCompass(315), "NW", "wind direction");
equal(context.windCompass(359), "N", "wrapped wind direction");
assert(timezoneMap.includes("assets/timezones/world-time-zones.svg"),
    "timezone presentation must use the geographic map asset");
assert(!timezoneMap.includes("Canvas"),
    "timezone presentation must not approximate zones with straight canvas bands");
assert(/class=["']z["']/.test(timezoneAsset),
    "timezone map must retain geographic timezone boundaries");
for (let offset = -12; offset < 14; offset++) {
    assert(colorDistance(timezoneBandColor(offset), timezoneBandColor(offset + 1)) >= 72,
        `adjacent UTC${offset} and UTC${offset + 1} bands need stronger contrast`);
}
assert(/\.z\s*\{stroke:#F4FAFF;\s*stroke-width:2\.2;/.test(timezoneAsset),
    "timezone boundaries must remain bright and visible at compact size");
assert(!/<text\b/.test(timezoneAsset),
    "compact timezone map must omit busy country and city labels");

console.log("weather presentation: artwork, local times, timezone maps, and wind direction passed");
