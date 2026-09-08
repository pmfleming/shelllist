#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, ""), context);
function equal(actual, expected, message) {
    if (actual !== expected)
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

equal(context.usageText({ cpu_percent: 2, memory_bytes: 64 * 1024 * 1024 }),
    "CPU 2.0% · 64.0 MiB", "usage summary preserves units");
const categoryFilters = context.categoryFilterOptions([
    { value: "shell", label: "Shell", icon: "shell-icon" },
    { value: "browser", label: "Browser", icon: "browser-icon" }
]);
equal(context.nextCategoryFilterOption(categoryFilters, "browser").value,
    "", "category action wraps to All");
equal(context.pageStatus({ applications: [{}], has_more: true, hyprland_available: false }),
    "1 application · more available · launch only", "unavailable window management remains explicit");
const retained = context.withoutClosedInstances({
    instances: [{ id: "one", focused: true }, { id: "two", focused: false }]
}, "close-window-1", "one");
equal(retained.running_count, 1, "closed window count");
equal(retained.focused, false, "closed focused window state");
console.log("application presentation: units, filtering and closed-window state passed");
