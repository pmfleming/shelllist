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
for (const metric of ["cpu_percent_of_machine", "memory_bytes", "gpu_busy_percent",
    "disk_read_bytes_per_second", "disk_write_bytes_per_second", "disk_space_total_bytes",
    "referenced_file_disk_bytes", "gpu_memory_allocated_bytes", "attributed_fraction"]) {
    assert.equal(typeof current[metric], "number", metric);
    assert.equal(resources.currentMetricAvailable(current, metric), true, metric);
    assert.equal(resources.historicalMetricAvailable(history, metric), true, metric);
    assert.equal(resources.historicalMetricAvailable({...history, [metric]: null}, metric), false, metric);
}
assert.equal(resources.currentMetricAvailable(current, "estimated_app_power_watts"), true);
assert.equal(resources.historicalMetricAvailable(history, "average_power_watts"), true);
for (const metric of ["network_receive_bytes_per_second", "network_transmit_bytes_per_second"]) {
    assert.equal(resources.currentMetricAvailable(current, metric), false, "unsupported is not idle");
    assert.equal(resources.historicalMetricAvailable(history, metric), false);
    assert.equal(resources.historicalMetricAvailable({...history,
        availability: {...history.availability, network_bytes: true}}, metric), true, "measured zero is valid");
}
assert.equal(resources.bytes(current.memory_bytes), "700 MiB");
assert.equal(resources.rate(current.disk_read_bytes_per_second), "512 KiB/s");
assert.equal(resources.power(current.estimated_app_power_watts), "2.22 W");
const badges = resources.metadataBadges({...current, running: true}, null);
assert.ok(badges.some(badge => badge.text === "96.0% coverage"));
assert.ok(badges.some(badge => badge.text === "2.0 s samples"));
assert.ok(badges.some(badge => badge.text === "Energy low" && badge.tone === "warning"));
const historical = resources.metadataBadges({running: false}, history);
assert.ok(historical.some(badge => badge.text === "Retained history"));
assert.ok(historical.some(badge => badge.text === "7 samples"));
assert.equal(resources.metadataBadges(null, null).length, 0);
console.log("application resources: live chart metrics, unavailable/idle distinction, formatting and provenance passed");
