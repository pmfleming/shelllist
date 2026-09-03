#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const timezoneMap = fs.readFileSync(process.argv[3], "utf8");
const timezoneAsset = fs.readFileSync(process.argv[4], "utf8");
const regionDirectory = process.argv[5];
const timeWeatherController = fs.readFileSync(process.argv[6], "utf8");
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
assert(timezoneMap.includes("assets/timezones/regions/")
        && timezoneMap.includes("regionIds"),
    "timezone presentation must load Rust-selected region assets");
assert(!timezoneMap.includes("TimezoneGeometry.js")
        && !timezoneMap.includes("data:image/svg+xml")
        && !timezoneMap.includes("Canvas"),
    "timezone presentation must keep generated geometry out of QML JavaScript");
assert(!timezoneMap.includes("WORLD TIME ZONES")
        && !timezoneMap.includes("selectedLabel"),
    "timezone map must not repeat the surrounding card heading and local time");
assert(/id=["']land-Europe-Paris["']/.test(timezoneAsset)
        && /id=["']land-America-New_York["']/.test(timezoneAsset),
    "timezone map must retain geographic IANA land shapes");
const oceanBands = [...timezoneAsset.matchAll(
    /<rect id="ocean-offset-([^"]+)" x="([^"]+)" width="([^"]+)"/g)];
assert(oceanBands.length === 25,
    "timezone map must include all 25 canonical whole-hour ocean bands");
assert(/id="ocean-offset-minus-12" x="0" width="15"/.test(timezoneAsset)
        && /id="ocean-offset-utc" x="345" width="30"/.test(timezoneAsset)
        && /id="ocean-offset-plus-12" x="705" width="15"/.test(timezoneAsset),
    "canonical ocean bands must cover the map continuously across the date line");
assert(!/<text\b/.test(timezoneAsset),
    "compact timezone map must omit busy country and city labels");

const regionAssets = fs.readdirSync(regionDirectory)
    .filter(name => name.endsWith(".svg"));
equal(regionAssets.length, 62,
    "all non-Antarctic timezone-boundary-builder regions must be retained");
for (const name of ["Europe-Paris.svg", "America-New_York.svg",
    "Pacific-Kiritimati.svg", "Pacific-Chatham.svg", "Pacific-Marquesas.svg"]) {
    assert(regionAssets.includes(name), `missing timezone region asset ${name}`);
    assert(/<path\b/.test(fs.readFileSync(path.join(regionDirectory, name), "utf8")),
        `timezone region asset ${name} must contain geometry`);
}
assert(timeWeatherController.includes("timezone_region_ids")
        && timezoneMap.includes("offsetSeconds % 3600 === 0")
        && timezoneMap.includes("locationMarker"),
    "timezone map must separate fractional ocean offsets and mark its location");

console.log("weather presentation: artwork, local times, timezone maps, and wind direction passed");
