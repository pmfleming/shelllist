#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const launcher = path.resolve(__dirname, "../launcher");
const Resources = {};
vm.createContext(Resources);
vm.runInContext(fs.readFileSync(path.join(launcher, "ApplicationResources.js"), "utf8")
    .replace(/^\.pragma library\s*/, ""), Resources);

const idle = { timestamp_ms: 15000, duration_ms: 15000, gpu_busy_percent: 0,
    disk_read_bytes_per_second: 0, network_receive_bytes_per_second: 0,
    availability: { gpu: true, storage: true, network_bytes: true } };
for (const metric of ["gpu_busy_percent", "disk_read_bytes_per_second", "network_receive_bytes_per_second"])
    assert.equal(Resources.historicalMetricAvailable(idle, metric), true, "idle is supported");
const unavailable = { timestamp_ms: 30000, duration_ms: 15000, gpu_busy_percent: 80,
    availability: { gpu: false } };
assert.equal(Resources.historicalMetricAvailable(unavailable, "gpu_busy_percent"), false);
assert.equal(Resources.historicalMetricAvailable({ gpu_busy_percent: 80 }, "gpu_busy_percent"), false,
    "legacy optional capability is unknown, even for nonzero values");
assert.equal(Resources.historicalMetricAvailable({ cpu_percent: 0, coverage: 1 }, "cpu_percent"), true);
assert.equal(Resources.currentMetricAvailable({ energy_source: "battery" }, "average_power_watts"), false,
    "battery discharge is system-only, not measured application power");
assert.equal(Resources.currentMetricAvailable({ measurement: { gpu_available: true } }, "gpu_busy_percent"), true);

// Exercise the actual Canvas segmentation function: unavailable buckets break
// the line even when the gap threshold alone would join their neighbours.
const source = fs.readFileSync(path.join(launcher, "ApplicationResourceLaneChart.qml"), "utf8");
const match = source.match(/                    function validSegments\((.*?)\) \{([\s\S]*?)\n                    \}/);
assert.ok(match);
const points = [idle, unavailable, { ...idle, timestamp_ms: 45000, gpu_busy_percent: 70 }];
const context = { Resources, chart: { points, timestamps: points.map(p => p.timestamp_ms),
    rangeStartMilliseconds: 0, rangeEndMilliseconds: 60000, maximumGapMilliseconds: 30000 },
    xFor: x => x, yFor: y => y };
vm.createContext(context);
vm.runInContext("function validSegments(" + match[1] + ") {" + match[2] + "\n}", context);
const segments = context.validSegments({ metric: "gpu_busy_percent" }, 0, 100);
assert.equal(segments.length, 2);
assert.equal(segments[0][0].y, 0);
assert.equal(segments[1][0].y, 70);
console.log("resource availability: idle, unknown, mixed and chart-gap checks passed");
