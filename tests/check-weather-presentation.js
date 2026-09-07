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
equal(context.utcOffset(-5 * 3600), "UTC−5", "negative UTC offset");
equal(context.utcOffset(5.5 * 3600), "UTC+5:30", "fractional UTC offset");
equal(context.duration(13 * 3600 + 32 * 60), "13 h 32 min", "day length");
equal(context.moonPhase(Date.UTC(2000, 0, 6, 18, 14)).name,
    "New moon", "known new moon");
function near(actual, expected, message) {
    if (Math.abs(actual - expected) > 0.000001)
        throw new Error(`${message}: expected ${expected}, got ${actual}`);
}

const sunrise = Date.UTC(2026, 5, 21, 6);
near(context.daylightFraction(sunrise, sunrise + 12 * 3600000), 0.5, "12-hour daylight ring");
near(context.daylightFraction(sunrise, sunrise + 18 * 3600000), 0.75, "long daylight ring");
equal(context.daylightFraction(0, 0), 0, "missing sun times");
equal(context.daylightFraction(sunrise, sunrise - 1), 0, "invalid sun times");
equal(context.daylightFraction(sunrise, sunrise + 30 * 3600000), 1, "daylight ring clamp");

const newMoon = Date.UTC(2000, 0, 6, 18, 14);
const monthMs = 29.530588853 * 86400000;
for (const [fraction, name, illumination, left, right] of [
    [0, "New moon", 0, 1, 1],
    [0.25, "First quarter", 50, 0, 1],
    [0.5, "Full moon", 100, -1, 1],
    [0.75, "Last quarter", 50, -1, 0]
]) {
    const moon = context.moonPhase(newMoon + fraction * monthMs);
    near(moon.fraction, fraction, `${name} phase fraction`);
    equal(moon.name, name, `${name} label`);
    equal(moon.illumination, illumination, `${name} illumination`);
    const bounds = context.moonLitBounds(moon.fraction, 0);
    near(bounds.left, left, `${name} illuminated left edge`);
    near(bounds.right, right, `${name} illuminated right edge`);
}
// Integrate the rendered disc to check crescent/gibbous shape and illumination agree.
for (const fraction of [0.125, 0.375, 0.625, 0.875]) {
    let area = 0;
    const steps = 10000;
    for (let step = 0; step < steps; ++step) {
        const y = -1 + (step + 0.5) * 2 / steps;
        const bounds = context.moonLitBounds(fraction, y);
        area += (bounds.right - bounds.left) * 2 / steps;
    }
    near(area / Math.PI, (1 - Math.cos(2 * Math.PI * fraction)) / 2,
        `phase ${fraction} rendered illumination`);
}

equal(context.windCompass(315), "NW", "wind direction");
equal(context.windCompass(359), "N", "wrapped wind direction");

console.log("weather presentation: artwork, local times, daylight, moon phases, and wind direction passed");
