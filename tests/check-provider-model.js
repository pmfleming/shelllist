#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const modelPath = process.argv[2];
if (!modelPath)
    throw new Error("usage: check-provider-model.js <Model.js>");

const source = fs.readFileSync(modelPath, "utf8").replace(/^\.pragma library\s*/, "");
const model = {};
vm.createContext(model);
vm.runInContext(source, model, { filename: modelPath });

let checks = 0;
function expect(label, condition) {
    ++checks;
    if (!condition)
        throw new Error(label);
}
function throws(label, action, fragment) {
    ++checks;
    try {
        action();
    } catch (error) {
        if (!fragment || String(error).includes(fragment))
            return;
        throw new Error(`${label}: wrong error: ${error}`);
    }
    throw new Error(`${label}: expected an error`);
}

throws("provider IDs are portable", () => model.provider({ id: "Bad ID", name: "Bad" }), "must match");

const launch = model.action({
    id: "launch",
    label: "Launch",
    role: "default",
    shortcut: "Enter",
    presentation: { group: "primary", tone: "active", width: 140 }
});
throws("action enums are checked", () => model.action({ id: "x", label: "X", role: "surprise" }), "unsupported value");

const terminal = model.result({
    providerId: "desktop.applications",
    id: "org.example.Terminal.desktop",
    title: "Terminal",
    subtitle: "System shell",
    keywords: ["console", "command line"],
    score: 25,
    primaryActionId: "launch",
    actions: [launch],
    payload: { desktopFile: "/tmp/terminal.desktop" }
});
throws("primary action must exist", () => model.result({
    providerId: "test", id: "one", title: "One", primaryActionId: "missing", actions: [launch]
}), "does not reference");
throws("duplicate actions are rejected", () => model.result({
    providerId: "test", id: "one", title: "One", actions: [launch, launch]
}), "duplicate");

const browser = model.result({
    providerId: "desktop.applications",
    id: "browser",
    title: "Web Browser",
    subtitle: "Browse the internet",
    keywords: ["firefox"],
    score: 100,
    actions: [launch]
});
const settings = model.result({
    providerId: "settings",
    id: "terminal-settings",
    title: "Terminal Settings",
    score: 5,
    actions: [launch]
});
let ranked = model.rankResults([browser, settings, terminal], "terminal");
expect("search filters every token", ranked.length === 2);
expect("exact title outranks title prefix", ranked[0].key === terminal.key);
ranked = model.rankResults([browser, terminal], "command line");
expect("keywords are searchable", ranked.length === 1 && ranked[0].key === terminal.key);
ranked = model.rankResults([terminal, browser], "");
expect("source score orders an empty query", ranked[0].key === browser.key);

throws("cross-provider batches rejected", () => model.resultBatch({ providerId: "settings", results: [terminal] }), "does not match");

// ProviderRegistry's Qt tests own dispatch routing and disabled-action rejection.

console.log(`Provider model: ${checks} checks passed`);
