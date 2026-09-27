#!/usr/bin/env node

const assert = require("node:assert/strict");
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

const launch = model.action({
    id: "launch",
    label: "Launch",
    role: "default",
    shortcut: "Enter",
    presentation: { group: "primary", tone: "active", width: 140 }
});

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
throws("duplicate actions are rejected", () => model.result({
    providerId: "test", id: "one", title: "One", actions: [launch, launch]
}), "duplicate");

throws("cross-provider batches rejected", () => model.resultBatch({ providerId: "settings", results: [terminal] }), "does not match");

for (const checked of [true, false, undefined]) {
    const options = { enabled: false, visible: false, presentation: { tone: "danger", width: 92 }, metadata: { disabledReason: "unsupported" } };
    const before = JSON.stringify(options);
    const expected = model.keepOpenAction("blocked", "Blocked", Object.assign({}, options, {
        kind: "toggle", state: { checked }, presentation: { group: "settings", tone: "danger", width: 92 }
    }));
    assert.deepEqual(model.settingToggle("blocked", "Blocked", checked, options), expected);
    assert.equal(JSON.stringify(options), before);
    ++checks;
}
const toggle = model.settingToggle("trusted", "Trusted", true);
assert.equal(toggle.presentation.group, "settings");
assert.equal(toggle.presentation.tone, "normal");
assert.equal(toggle.state.checked, true);
assert.equal(toggle.closePolicy, "keep-open");
++checks;

// ProviderRegistry's Qt tests own dispatch routing and disabled-action rejection.

console.log(`Provider model: ${checks} checks passed`);
