#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8")
    .replace(/^\.pragma\s+library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context, { filename: process.argv[2] });

function equal(actual, expected, label) {
    if (actual !== expected)
        throw new Error(`${label}: expected ${expected}, got ${actual}`);
}

// Catalog search, ordering and deduplication belong to Rust. Keep only
// presentation identity/action cases here; Qt covers the page consumer.
equal(context.groupRecords([{ app_name: "__proto__" }, { app_name: "constructor" }]).length,
    2, "app-controlled group keys cannot collide with object prototypes");

// Qt's Repeater-payload and selected-command workflows cover ordinary versus
// inline reply classification through actual consumers.
console.log("notification presentation: adversarial group identity passed");
