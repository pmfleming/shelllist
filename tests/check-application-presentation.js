#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

function equal(actual, expected, message) {
    if (actual !== expected)
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

equal(context.cpuText(1.26), "1.3%", "CPU rounds to one decimal");
equal(context.memoryText(512 * 1024 * 1024), "512 MiB", "memory formats MiB");
equal(context.memoryText(1.5 * 1024 * 1024 * 1024), "1.5 GiB", "memory formats GiB");
equal(context.usageText({ cpu_percent: 2, memory_bytes: 64 * 1024 * 1024 }), "CPU 2.0% · 64.0 MiB", "usage summary");
equal(context.rateText(2 * 1024 * 1024), "2.0 MiB/s", "I/O rate formats MiB per second");
equal(context.powerText(1.234), "1.23 W", "power formats watts");
equal(context.runningWindowIcon(1), "󰖯", "single-window icon");
equal(context.runningWindowIcon(3), "󰖲", "multiple-window icon");

console.log("application presentation: resource formatting and running icons passed");
