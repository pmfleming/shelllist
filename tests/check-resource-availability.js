#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const launcher = path.resolve(process.argv[2] || path.join(__dirname, "../launcher"));
const Resources = {};
vm.createContext(Resources);
vm.runInContext(fs.readFileSync(path.join(launcher, "ApplicationResources.js"), "utf8")
    .replace(/^\.pragma library\s*/, ""), Resources);
const plain = value => JSON.parse(JSON.stringify(value));

// Exercise the interval geometry actually consumed by every Canvas style.
const idle = { timestamp_ms: 15000, duration_ms: 15000, gpu_busy_percent: 0,
    disk_read_bytes_per_second: 0, disk_write_bytes_per_second: 4,
    availability: { gpu: true, storage: true } };
const unavailable = { ...idle, timestamp_ms: 30000, gpu_busy_percent: 80,
    availability: { gpu: false, storage: true } };
const resumed = { ...idle, timestamp_ms: 45000, gpu_busy_percent: 70 };
const segments = (points, metric = "gpu_busy_percent", start = 0, end = 60000) =>
    plain(Resources.historySegments(points, metric, start, end));
const gaps = (data, start = 0, end = 60000) => plain(Resources.missingIntervals(data, start, end));
assert.equal(Resources.currentMetricAvailable({ energy_source: "battery" }, "average_power_watts"), false,
    "battery discharge is not measured application power");
assert.deepEqual(segments([idle, unavailable, resumed]), [
    [{start: 0, end: 15000, value: 0}], [{start: 30000, end: 45000, value: 70}]
], "unsupported buckets break lines and areas; zero is a measured interval");
assert.deepEqual(gaps(segments([idle, unavailable, resumed])), [
    {start: 15000, end: 30000}, {start: 45000, end: 60000}
]);
assert.equal(segments([idle, {...idle, timestamp_ms: 30000, duration_ms: 1000}]).length, 2,
    "unobserved time breaks every trace, however short the timestamp gap");
assert.deepEqual(segments([idle, {...idle}]), [[{start: 0, end: 15000, value: 0}]],
    "duplicate ends never draw backward or paint duplicate columns");
assert.deepEqual(segments([{...idle, timestamp_ms: 30000, duration_ms: 10000}]), [
    [{start: 20000, end: 30000, value: 0}]
], "buckets cover preceding duration, not a centred radius");
assert.deepEqual(segments([idle, {...resumed, duration_ms: 45000}], "gpu_busy_percent", 10000, 40000), [
    [{start: 10000, end: 15000, value: 0}, {start: 15000, end: 40000, value: 70}]
], "clip both window edges and overlapping intervals; end-outside-window bucket still intersects");
assert.deepEqual(segments([idle, unavailable, {...resumed, duration_ms: 45000}]), [
    [{start: 0, end: 15000, value: 0}], [{start: 30000, end: 45000, value: 70}]
], "a long later bucket never fills a known unsupported interval");
for (const duration_ms of [0, -1, null, NaN, Infinity])
    assert.deepEqual(segments([{...idle, duration_ms}]), [], "invalid duration is not observed time");
assert.deepEqual(segments([idle], "gpu_busy_percent", 60000, 0), []);
assert.deepEqual(gaps([]), [{start: 0, end: 60000}]);
const directional = [idle, {...unavailable, disk_write_bytes_per_second: null}, resumed];
const reads = segments(directional, "disk_read_bytes_per_second");
const writes = segments(directional, "disk_write_bytes_per_second");
assert.equal(reads.length, 1);
assert.equal(writes.length, 2);
assert.deepEqual(gaps(writes)[0], {start: 15000, end: 30000}, "one valid direction does not conceal the other direction's gap");
console.log("resource availability: per-series gaps, clipped bucket geometry and measured zero passed");
