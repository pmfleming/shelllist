#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const history = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, ""), history);
const minute = 60000;
const day = 24 * 60 * minute;
function point(wall, active, percentage, continuous = true, extra = {}) {
    return { timestamp_ms: day + wall, active_time_ms: active, percentage,
        continuous, charging: false, ...extra };
}
function series(points, metric = "percentage") {
    return history.series(points, metric, metric === "percentage" ? 100 : 3600, false);
}
function equal(actual, expected, message) {
    assert.deepEqual(JSON.parse(JSON.stringify(actual)), expected, message);
}

const points = [
    point(0, 0, 100, false), point(15 * minute, 15 * minute, 90),
    point(2 * day, 15 * minute, 70, false),
    point(2 * day + 15 * minute, 30 * minute, 60)
];
const compact = series(points);
equal(compact.segments.map(segment => segment.map(p => p.x)), [[0, 0.5], [0.5, 1]],
    "two days offline must use no graph width or connecting line");
assert.equal(compact.activeDurationMs, 30 * minute);
assert.equal(compact.segments[1][0].timestamp_ms, 3 * day, "retain wall-clock labels");
assert.equal(history.activeDuration(points), "30m observed · sleep/offline time omitted");

const shortGap = series([point(0, 0, 80, false), point(minute, minute, 79),
    point(2 * minute, minute, 90, false), point(3 * minute, 2 * minute, 89)]);
equal(shortGap.segments.map(segment => segment.length), [2, 2],
    "explicit restart/sleep markers must split even a short wall-clock gap");

const isolated = series([point(0, 0, 100, false), point(day, 0, 80, false)]);
equal(isolated.segments.map(segment => segment.length), [1, 1], "retain every isolated sample");
equal(isolated.segments.map(segment => segment[0].x), [0.5, 0.5],
    "do not invent active duration between isolated samples");
assert.equal(series([{ timestamp_ms: day, percentage: 50 }]).hasActiveTimeline, false,
    "legacy/missing active coordinates must not fall back to calendar time");

const charging = series([
    point(0, 0, 20, false, { charging: true, time_to_full_seconds: 3600 }),
    point(minute, minute, 21, true, { time_to_full_seconds: 234972 }),
    point(2 * minute, 2 * minute, 22, true, { charging: true, time_to_full_seconds: null }),
    point(3 * minute, 3 * minute, 23, true, { charging: true, time_to_full_seconds: 0 }),
    point(4 * minute, 4 * minute, 24, true, { charging: true, time_to_full_seconds: 234972 }),
    point(5 * minute, 5 * minute, 25, true, { charging: true, time_to_full_seconds: 3000 })
], "time_to_full_seconds");
equal(charging.segments.map(segment => segment.map(p => p.value)), [[3600], [234972, 3000]],
    "only actual positive charging estimates may be plotted; missing data splits paths");
assert.equal(charging.maximum, 234972, "do not silently clamp real estimate outliers");
assert.equal(charging.segments[1][0].x, 0.8, "both graphs must share the full active timeline");

for (const invalid of [null, undefined, NaN, Infinity, -1, 101, "80"])
    assert.equal(series([point(0, 0, invalid, false)]).segments.length, 0);
for (const invalid of [null, undefined, NaN, Infinity, -1])
    assert.equal(series([point(0, invalid, 80, false)]).segments.length, 0);
const backwards = series([point(minute, minute, 80), point(0, 0, 70)]);
assert.equal(backwards.segments.length, 2, "never interpolate backwards through a clock reset");
assert.equal(series([]).segments.length, 0);
assert.equal(history.activeDuration([]), "Collecting active-time samples");
console.log("battery history: active-only axis, discontinuities, isolated samples and estimate validation passed");
