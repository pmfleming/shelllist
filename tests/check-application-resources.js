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

// Exercise the presentation the UI actually consumes, not the retired detail
// table's catalogue of every wire field. Rust still owns the complete fixture.
const cases = ["cpu_percent_of_machine", "memory_bytes", "gpu_busy_percent",
    "disk_read_bytes_per_second", "disk_write_bytes_per_second", "disk_space_total_bytes",
    "referenced_file_disk_bytes", "gpu_memory_allocated_bytes", "attributed_fraction"]
    .map(metric => [metric, {...history, [metric]: null}, false]);
for (const metric of ["network_receive_bytes_per_second", "network_transmit_bytes_per_second"])
    cases.push([metric, {...history, availability: {...history.availability, network_bytes: true}}, true]);
for (const [metric, point, available] of cases)
    assert.equal(resources.historicalMetricAvailable(point, metric), available, metric);
for (const metric of ["memory_bytes", "gpu_memory_allocated_bytes", "cpu_percent_of_machine", "disk_space_total_bytes", "referenced_file_disk_bytes", "disk_read_bytes_per_second"]) {
    assert.equal(resources.currentMetricAvailable(current, metric), true, metric);
    for (const value of [null, undefined, NaN, Infinity, -1, "0"]) {
        assert.equal(resources.currentMetricAvailable({...current, [metric]: value}, metric), false, metric + " rejects " + value);
        assert.equal(resources.historicalMetricAvailable({...history, [metric]: value}, metric), false);
    }
    assert.equal(resources.currentMetricAvailable({...current, [metric]: 0}, metric), true, "measured zero " + metric);
}
assert.equal(resources.currentMetricAvailable(current, "network_receive_bytes_per_second"), false, "connection support is not byte support");
assert.equal(resources.currentValue({...current, estimated_app_power_watts: 0, power_watts: 99}, "average_power_watts"), 0);
assert.equal(resources.currentMetricAvailable({...current, estimated_app_power_watts: null, power_watts: null}, "average_power_watts"), false);
assert.equal(resources.historicalMetricAvailable({...history, energy_source: "battery"}, "average_power_watts"), false);
assert.equal(resources.power(0), "0.00 W");
assert.equal(resources.power(0.004), "<0.01 W");
assert.equal(resources.energy(1500), "1.50 Wh");
assert.equal(resources.formatted(null, "bytes"), "Unavailable");
assert.equal(resources.rangeEnergyConfidence([]), "unknown");
assert.equal(resources.rangeEnergyConfidence([{...history, energy_confidence: "high"}, {...history, energy_confidence: "low"}]), "low");
assert.equal(resources.rangeEnergyConfidence([{...history, energy_confidence: "unknown"}]), "unknown");
assert.equal(resources.rangeEnergyConfidence([{...history, energy_confidence: "high"}, {...history, energy_confidence: "low", availability: {energy: false}}]), "high");

// Canonical means have already clipped buckets at the window edges. Integrating
// them must not extend partial coverage, sum lifetime counters, or require that
// all history pages happen to be present in a chart's current point array.
const summary = {
    window_start_ms: 1000, window_end_ms: 1801000, weighting: "observed-duration",
    metrics: {
        average_power_watts: {available: true, mean: 0.62, peak: 2.1, observed_ms: 1800000},
        disk_read_bytes_per_second: {available: true, mean: 100, peak: 400, observed_ms: 900000},
        disk_write_bytes_per_second: {available: true, mean: 0, peak: 0, observed_ms: 15000},
        network_receive_bytes_per_second: {available: false, mean: 0, peak: 0, observed_ms: 0}
    }
};
const validated = resources.windowSummary(summary, 1000, 1801000);
assert.equal(resources.periodEstimate(validated, "average_power_watts"), 310);
assert.equal(resources.periodEstimate(validated, "disk_read_bytes_per_second"), 90000);
assert.equal(resources.periodEstimate(validated, "disk_write_bytes_per_second"), 0);
assert.equal(resources.periodEstimate(validated, "network_receive_bytes_per_second"), null);
assert.equal(resources.observationText(validated, "disk_read_bytes_per_second"), "15.0 min observed / 30.0 min");
assert.equal(resources.compactObservation(validated, "disk_read_bytes_per_second"), "15m/30m");
assert.equal(resources.compactObservation(validated, "network_receive_bytes_per_second"), "—");
assert.equal(resources.periodText(validated, "average_power_watts"), "≈ 310.00 mWh");
assert.equal(resources.periodText(null, "average_power_watts"), "Unavailable");
assert.equal(resources.windowSummary(summary, 1000, 2000000), null, "stale range summary");
assert.equal(resources.windowSummary({...summary, weighting: "sample-count"}, 1000, 1801000), null);
for (const stats of [
    {mean: null}, {mean: Infinity}, {mean: -2}, {observed_ms: 0},
    {observed_ms: -1}, {observed_ms: 1800001}, {observed_ms: NaN}, {available: false}
]) {
    const changed = {...summary, metrics: {average_power_watts: {...summary.metrics.average_power_watts, ...stats}}};
    assert.equal(resources.periodEstimate(changed, "average_power_watts"), null, JSON.stringify(stats));
}
assert.equal(resources.periodEstimate({...summary, metrics: {memory_bytes: {available: true, mean: 100, observed_ms: 10}}}, "memory_bytes"), null, "do not integrate space metrics");
console.log("application resources: scoped metrics, availability, precision and observed-window estimates passed");
