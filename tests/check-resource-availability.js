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

// check-application-resources owns null/availability validation. This suite
// checks actual canvas gaps and rejects system battery power as per-app data.
const idle = { timestamp_ms: 15000, duration_ms: 15000, gpu_busy_percent: 0,
    disk_read_bytes_per_second: 0, network_receive_bytes_per_second: 0,
    availability: { gpu: true, storage: true, network_bytes: true } };
const unavailable = { timestamp_ms: 30000, duration_ms: 15000, gpu_busy_percent: 80,
    availability: { gpu: false } };
assert.equal(Resources.currentMetricAvailable({ energy_source: "battery" }, "average_power_watts"), false,
    "battery discharge is system-only, not measured application power");

// Exercise the actual Canvas segmentation function: unavailable buckets break
// the line even when the gap threshold alone would join their neighbours.
const source = fs.readFileSync(path.join(launcher, "ApplicationResourceLaneChart.qml"), "utf8");
const lift = name => source.match(new RegExp("^                    function " + name + "\\([\\s\\S]*?\\n                    \\}", "m"))[0];
const points = [idle, unavailable, { ...idle, timestamp_ms: 45000, gpu_busy_percent: 70 }];
const context = { Resources, chart: { points, timestamps: points.map(p => p.timestamp_ms),
    rangeStartMilliseconds: 0, rangeEndMilliseconds: 60000, maximumGapMilliseconds: 30000 },
    xFor: x => x, yFor: y => y };
vm.createContext(context);
vm.runInContext(lift("sampleAt") + "\n" + lift("validSegments"), context);
const segments = context.validSegments({ metric: "gpu_busy_percent" }, 0, 100);
assert.equal(segments.length, 2);
context.chart.points = [idle, {...idle, timestamp_ms: 30000, duration_ms: 1000}];
context.chart.timestamps = context.chart.points.map(p => p.timestamp_ms);
assert.equal(context.validSegments({metric: "gpu_busy_percent"}, 0, 100).length, 2,
    "unobserved time breaks traces even below the maximum timestamp-gap threshold");
context.chart.points = [idle, {...idle}];
context.chart.timestamps = context.chart.points.map(p => p.timestamp_ms);
assert.equal(context.validSegments({metric: "gpu_busy_percent"}, 0, 100).length, 2,
    "duplicate/non-advancing timestamps cannot draw backward or duplicate segments");

const regions = [];
Object.assign(context, {
    lane: {modelData: {unavailable: false, series: [{metric: "gpu_busy_percent"}]}},
    width: 60000, dimRegion: (_canvas, start, end) => regions.push([start, end])
});
context.chart.points = [{...idle, timestamp_ms: 30000, duration_ms: 10000}];
vm.runInContext(lift("drawUnavailablePeriods"), context);
context.drawUnavailablePeriods({});
assert.deepEqual(regions, [[0, 20000], [30000, 60000]], "buckets cover time before their end, not a centred radius");
console.log("resource availability: measured power, interval geometry and unavailable chart gaps passed");
