#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const timezoneMap = fs.readFileSync(process.argv[3], "utf8");
const timezoneAsset = fs.readFileSync(process.argv[4], "utf8");
const timezoneGeometry = fs.readFileSync(process.argv[5], "utf8");
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
assert(/id=["']Europe-Paris["']/.test(timezoneAsset)
        && /id=["']America-New_York["']/.test(timezoneAsset),
    "timezone map must retain geographic IANA regional shapes");
assert(!/<rect\b/.test(timezoneAsset),
    "timezone map must not render offsets as straight bands");
assert(!/<text\b/.test(timezoneAsset),
    "compact timezone map must omit busy country and city labels");
assert(timezoneGeometry.includes('"Europe/Amsterdam":"Europe/Paris"'),
    "timezone aliases must resolve to highlightable geometry");
assert(timezoneMap.includes("selectedZoneSource()")
        && timezoneMap.includes("locationMarker"),
    "timezone map must highlight the selected zone and mark its location");

console.log("weather presentation: artwork, local times, timezone maps, and wind direction passed");
