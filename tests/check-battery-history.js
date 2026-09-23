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
    "two days offline must use no graph width or solid connecting line");
equal(compact.breaks.map(gap => [[gap.from.x, gap.from.value], [gap.to.x, gap.to.value]]),
    [[[0.5, 90], [0.5, 70]]],
    "connect only the last charge reading before downtime to the first after it");

const shortGap = series([point(0, 0, 80, false), point(minute, minute, 79),
    point(2 * minute, minute, 90, false), point(3 * minute, 2 * minute, 89)]);
equal(shortGap.segments.map(segment => segment.length), [2, 2],
    "explicit restart/suspend markers must split even a short wall-clock gap");
assert.equal(series([point(0, 0, 80), point(minute, minute, null),
    point(2 * minute, 2 * minute, 79)]).breaks.length, 0,
    "missing charge readings must not fabricate gap endpoints");

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
const areas = history.powerAreas(watts.segments);
equal(areas.map(area => [area.charging, area.points.map(p => p.value)]),
    [[false, [0]], [false, [12, 0]], [true, [0, 8]]],
    "power areas split at missing samples and change colour through zero");
const suspendedWatts = series([
    point(0, 0, 80, false, { power_watts: 12 }),
    point(minute, minute, 79, true, { power_watts: 8 }),
    point(day, minute, 60, false, { power_watts: 20 }),
    point(day + minute, 2 * minute, 59, true, { power_watts: 10 })
], "power_watts");
equal(history.powerAreas(suspendedWatts.segments).map(area => area.points.map(p => p.value)),
    [[12, 8], [20, 10]], "same-direction areas must not connect across suspend");
const zeroTransition = series([
    point(0, 0, 80, false, { power_watts: 0, power_valid: true }),
    point(minute, minute, 80, true, { power_watts: 0, power_valid: true, charging: true })
], "power_watts");
const zeroAreas = history.powerAreas(zeroTransition.segments);
assert.equal(zeroAreas[0].points[1].x, 0.5, "zero-to-zero mode changes remain finite");
// Qt's BatteryHistory suite owns visible isolated samples, range selection and
// appending live observations. Keep duplicate/late cache handling below.
const live = point(2 * day + 16 * minute, 31 * minute, 59);
const extended = history.windowPoints(points, 6, live);
assert.equal(history.windowPoints(extended, 6, live).length, 5, "do not duplicate a persisted/live point");
assert.equal(history.windowPoints(extended, 6, points[1]).length, 5, "late metadata cannot rewind a newer response");
console.log("battery history: chart coordinates, invalid samples, discontinuities and live cache handling passed");
