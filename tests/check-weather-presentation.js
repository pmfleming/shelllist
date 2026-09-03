#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const timezoneMap = fs.readFileSync(process.argv[3], "utf8");
const timezoneAsset = fs.readFileSync(process.argv[4], "utf8");
const timezoneGeometry = fs.readFileSync(process.argv[5], "utf8");
const geometrySource = timezoneGeometry.replace(/^\.pragma library\s*$/m, "");
const context = { Date, Number, Math, String };
vm.createContext(context);
vm.runInContext(source, context);
const geometryContext = { Date, Number, Math, String };
vm.createContext(geometryContext);
vm.runInContext(geometrySource, geometryContext);

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
assert(/id=["']land-Europe-Paris["']/.test(timezoneAsset)
        && /id=["']land-America-New_York["']/.test(timezoneAsset),
    "timezone map must retain geographic IANA land shapes");
const oceanBands = [...timezoneAsset.matchAll(/<rect id="ocean-offset-([^"]+)" x="([^"]+)" width="([^"]+)"/g)];
assert(oceanBands.length === 25,
    "timezone map must include all 25 canonical whole-hour ocean bands");
assert(/id="ocean-offset-minus-12" x="0" width="15"/.test(timezoneAsset)
        && /id="ocean-offset-utc" x="345" width="30"/.test(timezoneAsset)
        && /id="ocean-offset-plus-12" x="705" width="15"/.test(timezoneAsset),
    "canonical ocean bands must cover the map continuously across the date line");
assert(!/<text\b/.test(timezoneAsset),
    "compact timezone map must omit busy country and city labels");
const parisPath = vm.runInContext('LAND_PATHS["Europe/Paris"]', geometryContext);
const johannesburgPath = vm.runInContext('LAND_PATHS["Africa/Johannesburg"]', geometryContext);
const kolkataPath = vm.runInContext('LAND_PATHS["Asia/Kolkata"]', geometryContext);
const karachiPath = vm.runInContext('LAND_PATHS["Asia/Karachi"]', geometryContext);
const summerUtc2 = geometryContext.landPathForOffset(2 * 3600, Date.UTC(2026, 6, 1));
const winterUtc1 = geometryContext.landPathForOffset(1 * 3600, Date.UTC(2026, 0, 1));
const fractionalUtc530 = geometryContext.landPathForOffset(5.5 * 3600, Date.UTC(2026, 6, 1));
assert(summerUtc2.includes(parisPath) && summerUtc2.includes(johannesburgPath)
        && winterUtc1.includes(parisPath),
    "offset highlighting must include every region at that seasonal UTC offset");
assert(fractionalUtc530.includes(kolkataPath) && !fractionalUtc530.includes(karachiPath),
    "fractional-hour timezone exceptions must remain separate");
const canonicalOffsets = [
    ["Europe/London", 0, 3600],
    ["Europe/Paris", 3600, 7200],
    ["America/New_York", -18000, -14400],
    ["Australia/Sydney", 39600, 36000],
    ["Asia/Kolkata", 19800, 19800],
    ["Pacific/Chatham", 49500, 45900],
    ["Pacific/Kiritimati", 50400, 50400]
];
for (const [timezone, januaryOffset, julyOffset] of canonicalOffsets) {
    const schedule = vm.runInContext(`OFFSET_SCHEDULES["${timezone}"]`, geometryContext);
    equal(geometryContext.offsetAt(schedule, Date.UTC(2026, 0, 15)), januaryOffset,
        `${timezone} canonical January offset`);
    equal(geometryContext.offsetAt(schedule, Date.UTC(2026, 6, 15)), julyOffset,
        `${timezone} canonical July offset`);
}
const landZones = vm.runInContext("Object.keys(LAND_PATHS)", geometryContext);
equal(landZones.length, 62,
    "all non-Antarctic timezone-boundary-builder regions must be retained");
assert(landZones.includes("Pacific/Kiritimati")
        && landZones.includes("Pacific/Chatham")
        && landZones.includes("Pacific/Marquesas"),
    "small and fractional-offset island regions must not be simplified away");
for (const instant of [Date.UTC(2026, 0, 15), Date.UTC(2026, 6, 15)]) {
    for (const timezone of landZones) {
        const schedule = vm.runInContext(`OFFSET_SCHEDULES["${timezone}"]`, geometryContext);
        const path = vm.runInContext(`LAND_PATHS["${timezone}"]`, geometryContext);
        const offset = geometryContext.offsetAt(schedule, instant);
        assert(geometryContext.landPathForOffset(offset, instant).includes(path),
            `${timezone} must appear in its rendered UTC-offset region`);
    }
}
for (let offset = -12; offset <= 12; ++offset) {
    const band = geometryContext.oceanBandForOffset(offset * 3600);
    equal(band.x, offset === -12 ? 0 : (offset * 15 + 180) * 2 - 15,
        `UTC${offset} canonical ocean band position`);
    equal(band.width, Math.abs(offset) === 12 ? 15 : 30,
        `UTC${offset} canonical ocean band width`);
}
equal(geometryContext.oceanBandForOffset(5.5 * 3600).width, 0,
    "fractional offsets must not claim canonical ocean bands");
assert(timezoneMap.includes("selectedOffsetSource()")
        && timezoneMap.includes("landPathForOffset(offsetSeconds")
        && timezoneMap.includes("oceanBandForOffset(offsetSeconds)")
        && timezoneMap.includes("locationMarker"),
    "timezone map must highlight the selected UTC offset and mark its location");

console.log("weather presentation: artwork, local times, timezone maps, and wind direction passed");
