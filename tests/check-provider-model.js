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

const descriptor = model.provider({ id: "desktop.applications", name: "Applications", prefixes: [">", ">"] });
expect("provider schema version", descriptor.schemaVersion === 1);
expect("provider defaults enabled", descriptor.enabled === true);
expect("provider prefixes deduplicated", descriptor.prefixes.length === 1);
throws("provider IDs are portable", () => model.provider({ id: "Bad ID", name: "Bad" }), "must match");

const launch = model.action({
    id: "launch",
    label: "Launch",
    role: "default",
    shortcut: "Enter",
    presentation: { group: "primary", tone: "active", width: 140 }
});
expect("action is enabled by default", launch.enabled === true);
expect("action presentation is normalized", launch.presentation.group === "primary" && launch.presentation.width === 140);
const keepOpen = model.keepOpenAction("refresh", "Refresh", { role: "default" });
expect("shared provider actions stay open", keepOpen.closePolicy === "keep-open" && keepOpen.role === "default");
throws("action enums are checked", () => model.action({ id: "x", label: "X", role: "surprise" }), "unsupported value");
throws("only one visible primary action is allowed", () => model.actionList([
    { id: "first", label: "First", presentation: { group: "primary" } },
    { id: "second", label: "Second", presentation: { group: "primary" } }
]), "at most one visible primary");
expect("hidden primary state alternatives are allowed", model.actionList([
    { id: "connected", label: "Disconnect", presentation: { group: "primary" } },
    { id: "disconnected", label: "Connect", visible: false, presentation: { group: "primary" } }
]).length === 2);

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
expect("result has collision-safe key", terminal.key === "desktop.applications::org.example.Terminal.desktop");
expect("result keeps provider payload", terminal.payload.desktopFile === "/tmp/terminal.desktop");
throws("primary action must exist", () => model.result({
    providerId: "test", id: "one", title: "One", primaryActionId: "missing", actions: [launch]
}), "does not reference");
throws("primary action uses primary presentation", () => model.result({
    providerId: "test", id: "one", title: "One", primaryActionId: "secondary",
    actions: [{ id: "secondary", label: "Secondary", presentation: { group: "toolbar" } }]
}), "must reference a primary presentation action");
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

const query = model.queryRequest({ id: "query-1", generation: 2, text: "term", limit: 0 });
expect("query generation retained", query.generation === 2);
expect("query limit is bounded", query.limit === 1);

const batch = model.resultBatch({ providerId: "desktop.applications", queryId: "query-1", results: [terminal] });
expect("batch results normalized", batch.results[0].key === terminal.key);
throws("cross-provider batches rejected", () => model.resultBatch({ providerId: "settings", results: [terminal] }), "does not match");

const execution = model.executionRequest({ id: "action-1", result: terminal, action: launch, context: { workspace: "2" } });
expect("execution routes by provider", execution.providerId === "desktop.applications");
expect("execution routes by stable result", execution.resultKey === terminal.key);
expect("execution routes by action ID", execution.actionId === "launch");
throws("disabled actions cannot execute", () => model.executionRequest({
    id: "action-2",
    result: terminal,
    action: { id: "launch", label: "Launch", enabled: false }
}), "visible and enabled");

console.log(`Provider model: ${checks} checks passed`);
