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

// Projection consumes native membership/order; it must not mutate its window.
const preview = {id: 2, created_unix_ms: 2000, summary: "Stack", app_key: "chat"};
const snapshot = {recent: [{id: 1, created_unix_ms: 1000}], date: "older",
    dates: [{key: "today", count: 0}, {key: "week", count: 1}, {key: "older", count: 2}]};
const entries = [{key: "2:2000", preview, members: [{id: 2, created: 2000}, {id: 3, created: 3000}]}];
const original = JSON.stringify({snapshot, entries});
const rows = context.timelineRows(snapshot, "older", false, entries, {"2:2000": true}, true);
equal(rows.map(row => row.key).join(), "1:1000,week,older,2:2000,member:2:2000,member:3:3000,more", "native order and stable member identities");
equal(rows[5].preview.summary, "Stack", "members retain the native preview content");
equal(rows[5].preview.id, 3, "member identity replaces only the preview identity");
equal(JSON.stringify({snapshot, entries}), original, "projection leaves its window untouched");
for (const [date, collapsed] of [["older", true], ["today", false]])
    equal(context.timelineRows(snapshot, date, collapsed, entries, {}, true).map(row => row.key).join(),
        "1:1000,week,older", "closed or superseded periods cannot expose entries or load-more");

// Qt's Repeater-payload and selected-command workflows cover ordinary versus
// inline reply classification through actual consumers.
console.log("notification presentation: adversarial identity and timeline projection passed");
