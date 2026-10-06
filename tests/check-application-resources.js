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
const {history_point: history} = JSON.parse(fs.readFileSync(fixturePath, "utf8"));

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
console.log("application resources: live metrics and unavailable/idle distinction passed");
