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

// Interval arithmetic belongs here, rather than repeated Canvas-style fixtures.
const idle = {timestamp_ms: 15000, duration_ms: 15000, gpu_busy_percent: 0,
    disk_read_bytes_per_second: 0, disk_write_bytes_per_second: 4,
    availability: {gpu: true, storage: true}};
const unavailable = {...idle, timestamp_ms: 30000, gpu_busy_percent: 80,
    availability: {gpu: false, storage: true}};
const resumed = {...idle, timestamp_ms: 45000, gpu_busy_percent: 70};
const cases = [
    {label: "unsupported buckets break traces; zero is measured", points: [idle, unavailable, resumed],
        segments: [[{start: 0, end: 15000, value: 0}], [{start: 30000, end: 45000, value: 70}]],
        gaps: [{start: 15000, end: 30000}, {start: 45000, end: 60000}]},
    {label: "short unobserved interval", points: [idle, {...idle, timestamp_ms: 30000, duration_ms: 1000}],
        segments: [[{start: 0, end: 15000, value: 0}], [{start: 29000, end: 30000, value: 0}]],
        gaps: [{start: 15000, end: 29000}, {start: 30000, end: 60000}]},
    {label: "duplicate ends cannot paint duplicate columns", points: [idle, {...idle}],
        segments: [[{start: 0, end: 15000, value: 0}]], gaps: [{start: 15000, end: 60000}]},
    {label: "buckets cover preceding duration", points: [{...idle, timestamp_ms: 30000, duration_ms: 10000}],
        segments: [[{start: 20000, end: 30000, value: 0}]], gaps: [{start: 0, end: 20000}, {start: 30000, end: 60000}]},
    {label: "clip both window edges and overlapping intervals", points: [idle, {...resumed, duration_ms: 45000}], start: 10000, end: 40000,
        segments: [[{start: 10000, end: 15000, value: 0}, {start: 15000, end: 40000, value: 70}]], gaps: []},
    {label: "long later buckets cannot fill known unsupported time", points: [idle, unavailable, {...resumed, duration_ms: 45000}],
        segments: [[{start: 0, end: 15000, value: 0}], [{start: 30000, end: 45000, value: 70}]],
        gaps: [{start: 15000, end: 30000}, {start: 45000, end: 60000}]},
    {label: "inverted range", points: [idle], start: 60000, end: 0, segments: [], gaps: []},
    {label: "no observations", points: [], segments: [], gaps: [{start: 0, end: 60000}]}
];
for (const duration_ms of [0, -1, null, NaN, Infinity])
    cases.push({label: "invalid duration " + duration_ms, points: [{...idle, duration_ms}],
        segments: [], gaps: [{start: 0, end: 60000}]});
for (const data of cases) {
    const start = data.start ?? 0, end = data.end ?? 60000;
    const segments = Resources.historySegments(data.points, "gpu_busy_percent", start, end);
    assert.deepEqual(plain({segments, gaps: Resources.missingIntervals(segments, start, end)}),
        {segments: data.segments, gaps: data.gaps}, data.label);
}
const directional = [idle, {...unavailable, disk_write_bytes_per_second: null}, resumed];
const reads = Resources.historySegments(directional, "disk_read_bytes_per_second", 0, 60000);
const writes = Resources.historySegments(directional, "disk_write_bytes_per_second", 0, 60000);
assert.deepEqual(plain({readSegments: reads.length, writeSegments: writes.length, gaps: Resources.missingIntervals(writes, 0, 60000)}),
    {readSegments: 1, writeSegments: 2, gaps: [{start: 15000, end: 30000}, {start: 45000, end: 60000}]},
    "one valid direction cannot conceal the other direction's gap");
console.log("resource availability: per-series gaps, clipped bucket geometry and measured zero passed");
