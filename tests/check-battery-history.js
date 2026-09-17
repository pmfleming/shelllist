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
assert.equal(compact.segments[1][0].timestamp_ms, 3 * day, "retain wall-clock labels");

const shortGap = series([point(0, 0, 80, false), point(minute, minute, 79),
    point(2 * minute, minute, 90, false), point(3 * minute, 2 * minute, 89)]);
equal(shortGap.segments.map(segment => segment.length), [2, 2],
    "explicit restart/sleep markers must split even a short wall-clock gap");

const isolated = series([point(0, 0, 100, false), point(day, 0, 80, false)]);
equal(isolated.segments.map(segment => segment.length), [1, 1], "retain every isolated sample");
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

const watts = series([
    point(0, 0, 80, false, { power_watts: 0, power_valid: false }),
    point(minute, minute, 79, true, { power_watts: 0, power_valid: true }),
    point(2 * minute, 2 * minute, 78, true, { power_watts: 15, power_valid: false }),
    point(3 * minute, 3 * minute, 77, true, { power_watts: 12 }),
    point(4 * minute, 4 * minute, 78, true, { power_watts: 8, charging: true })
], "power_watts");
equal(watts.segments.map(s => s.map(p => p.value)), [[0], [12, 8]],
    "unknown and legacy-zero power must not be presented as measured zero");
assert.equal(watts.segments[1][1].charging, true, "preserve charge direction for power bars");
equal(history.windowPoints(points, 0.25).map(p => p.percentage), [90, 70, 60],
    "range controls use observed time and retain both sides of sleep discontinuities");
const live = point(2 * day + 16 * minute, 31 * minute, 59);
const extended = history.windowPoints(points, 6, live);
assert.equal(extended.length, 5, "append the live observation between persisted buckets");
assert.equal(series(extended).activeDurationMs, 31 * minute);
assert.equal(history.windowPoints(extended, 6, live).length, 5, "do not duplicate a persisted/live point");
assert.equal(history.windowPoints(extended, 6, points[1]).length, 5, "late metadata cannot rewind a newer response");
assert.equal(points.length, 4, "windowing must not mutate the history cache");
// Domain energy/forecast cases now live in bar-daemon/src/battery/derived.rs.
assert.equal(history.energySeries, undefined, "no frontend integration fallback");
assert.equal(history.chargeForecast, undefined, "no frontend forecast fallback");
console.log("battery history: chart coordinates, discontinuities and domain boundary passed");
