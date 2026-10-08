#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const [resourcesPath, fixturePath] = process.argv.slice(2);
if (!resourcesPath || !fixturePath)
    throw new Error("usage: check-application-resources.js <ApplicationResources.js> <fixture.json>");
const resources = {};
vm.createContext(resources);
vm.runInContext(fs.readFileSync(resourcesPath, "utf8").replace(/^\.pragma library\s*/, ""), resources);
const {current, history_point: history} = JSON.parse(fs.readFileSync(fixturePath, "utf8"));

// Keep validation boundaries at the pure-model layer; native tests own display
// formatting, field transactions, source replacement and canonical-total wiring.
const cases = ["cpu_percent_of_machine", "memory_bytes", "gpu_busy_percent",
    "disk_read_bytes_per_second", "disk_write_bytes_per_second", "disk_space_total_bytes",
    "referenced_file_disk_bytes", "gpu_memory_allocated_bytes", "attributed_fraction"]
    .map(metric => [metric, {...history, [metric]: null}, false]);
for (const metric of ["network_receive_bytes_per_second", "network_transmit_bytes_per_second"])
    cases.push([metric, {...history, metric_availability: {...history.metric_availability, [metric]: true}}, true]);
for (const [metric, point, available] of cases)
    assert.equal(resources.historicalMetricAvailable(point, metric), available, metric);
for (const metric of ["memory_bytes", "gpu_memory_allocated_bytes", "cpu_percent_of_machine", "disk_space_total_bytes", "referenced_file_disk_bytes", "disk_read_bytes_per_second"]) {
    for (const value of [current[metric], 0])
        assert.equal(resources.currentMetricAvailable({...current, [metric]: value}, metric), true, metric + " measured " + value);
    for (const value of [null, undefined, NaN, Infinity, -1, "0"])
        assert.deepEqual({current: resources.currentMetricAvailable({...current, [metric]: value}, metric),
            history: resources.historicalMetricAvailable({...history, [metric]: value}, metric)},
        {current: false, history: false}, metric + " rejects " + value);
}
for (const [label, actual, expected] of [
    ["connection support is not byte support", resources.currentMetricAvailable(current, "network_receive_bytes_per_second"), false],
    ["zero power is not a fallback", resources.currentValue({...current, estimated_app_power_watts: 0, power_watts: 99}, "average_power_watts"), 0],
    ["missing power", resources.currentMetricAvailable({...current, estimated_app_power_watts: null, power_watts: null}, "average_power_watts"), false],
    ["native unavailability", resources.historicalMetricAvailable({...history, metric_availability: {average_power_watts: false}}, "average_power_watts"), false],
    ["missing projection is not reconstructed", resources.currentMetricAvailable({...current, metric_availability: undefined}, "memory_bytes"), false],
    ["empty confidence", resources.rangeEnergyConfidence(null), "unknown"],
    ["native confidence", resources.rangeEnergyConfidence({energy_confidence: "low"}), "low"],
    ["unknown confidence", resources.rangeEnergyConfidence({energy_confidence: "unrecognized"}), "unknown"]
])
    assert.equal(actual, expected, label);

// Consume native totals verbatim, never integrate rates in the frontend.
const summary = {
    window_start_ms: 1000, window_end_ms: 1801000, weighting: "observed-duration",
    metrics: {
        average_power_watts: {available: true, mean: 0.62, peak: 2.1, observed_ms: 1800000, observed_total: 311, total_unit: "mWh"},
        disk_read_bytes_per_second: {available: true, mean: 100, peak: 400, observed_ms: 900000, observed_total: 90001, total_unit: "bytes"},
        disk_write_bytes_per_second: {available: true, mean: 0, peak: 0, observed_ms: 15000, observed_total: 0, total_unit: "bytes"},
        network_receive_bytes_per_second: {available: false, mean: 0, peak: 0, observed_ms: 0}
    }
};
const validated = resources.windowSummary(summary, 1000, 1801000);
for (const [metric, expected] of Object.entries({average_power_watts: 311,
    disk_read_bytes_per_second: 90001, disk_write_bytes_per_second: 0, network_receive_bytes_per_second: null}))
    assert.equal(resources.periodEstimate(validated, metric), expected, metric);
const invalid = [
    ["stale range", resources.windowSummary(summary, 1000, 2000000)],
    ["unknown weighting", resources.windowSummary({...summary, weighting: "sample-count"}, 1000, 1801000)],
    ["non-rate metric", {...summary, metrics: {memory_bytes: {available: true, mean: 100, observed_ms: 10}}}, "memory_bytes"]
];
for (const stats of [{observed_total: null}, {observed_total: -1}, {observed_total: Infinity}, {total_unit: "unknown"}, {mean: null}, {mean: Infinity}, {mean: -2}, {observed_ms: 0},
    {observed_ms: -1}, {observed_ms: 1800001}, {observed_ms: NaN}, {available: false}])
    invalid.push([JSON.stringify(stats), {...summary, metrics: {average_power_watts: {...summary.metrics.average_power_watts, ...stats}}}]);
for (const [label, value, metric] of invalid)
    assert.equal(resources.periodEstimate(value, metric || "average_power_watts"), null, label);
console.log("application resources: availability, power attribution and observed-window estimates passed");
