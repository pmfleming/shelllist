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
const points = [
    point(0, 0, 100, false), point(15 * minute, 15 * minute, 90),
    point(2 * day, 15 * minute, 70, false),
    point(2 * day + 15 * minute, 30 * minute, 60)
];
const cases = [
    {label: "missing readings do not fabricate gap endpoints", points: [point(0, 0, 80), point(minute, minute, null), point(2 * minute, 2 * minute, 79)], field: "breaks", count: 0},
    {label: "clock reset breaks interpolation", points: [point(minute, minute, 80), point(0, 0, 70)], field: "segments", count: 2},
    ...[null, undefined, NaN, Infinity, -1, 101, "80"].map(value => ({label: `invalid percentage ${value}`, points: [point(0, 0, value, false)], field: "segments", count: 0}))
];
for (const sample of cases)
    assert.equal(series(sample.points)[sample.field].length, sample.count, sample.label);

const watts = series([
    point(0, 0, 80, false, { power_watts: 0, power_valid: false }),
    point(minute, minute, 79, true, { power_watts: 0, power_valid: true }),
    point(2 * minute, 2 * minute, 78, true, { power_watts: 15, power_valid: false }),
    point(3 * minute, 3 * minute, 77, true, { power_watts: 12 }),
    point(4 * minute, 4 * minute, 78, true, { power_watts: 8, charging: true })
], "power_watts");
const areas = history.powerAreas(watts.segments);
assert.deepEqual(JSON.parse(JSON.stringify(areas.map(area => [area.charging, area.points.map(p => p.value)]))),
    [[false, [0]], [false, [12, 0]], [true, [0, 8]]],
    "power areas split at missing samples and change colour through zero");
const zeroTransition = series([
    point(0, 0, 80, false, { power_watts: 0, power_valid: true }),
    point(minute, minute, 80, true, { power_watts: 0, power_valid: true, charging: true })
], "power_watts");
const zeroAreas = history.powerAreas(zeroTransition.segments);
assert.equal(zeroAreas[0].points[1].x, 0.5, "zero-to-zero mode changes remain finite");
// Keep protection against late cache data; Qt covers explicit inspection,
// while exact chart pixels are intentionally outside the retained suite.
const live = point(2 * day + 16 * minute, 31 * minute, 59);
const extended = history.windowPoints(points, 6, live);
assert.equal(history.windowPoints(extended, 6, points[1]).length, 5, "late metadata cannot rewind a newer response");
console.log("battery history: invalid samples, discontinuities and live cache handling passed");
