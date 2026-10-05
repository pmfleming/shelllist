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

// The Qt notification suite exercises identity through real drafts and replies.
const actions = {actions: [{key: "reply"}, {key: "mail-reply-sender"}, {key: "inline-reply"}, {key: "default"}]};
equal(context.standardActions(actions).map(action => action.key).join(","), "reply,mail-reply-sender", "ordinary reply actions remain callable");
equal(context.replyAction(actions).key, "inline-reply", "inline reply is an exact extension key");
console.log("notification presentation: adversarial identity and action classification passed");
