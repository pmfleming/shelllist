#!/usr/bin/env node
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const model = {};
vm.createContext(model);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*/m, ""), model);
const plain = value => JSON.parse(JSON.stringify(value));
const outputs = [
    { id: 0, name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, scale: 1.25, x: -1536, y: 0, transform: 0, disabled: true, availableModes: ["1920x1200@60.000Hz"] },
    { id: 1, name: "DP-1", description: "Desk", width: 3840, height: 2160, refreshRate: 59.94, scale: 1.5, x: 0, y: 0, transform: 0, disabled: false, availableModes: ["3840x2160@59.940Hz", "3840x2160@60.00Hz", "2560x1440@120.00Hz"] }
];
const draft = model.draft(outputs);
assert.equal(draft[0].enabled, false, "draft preserves the observed disabled laptop");
assert.equal(model.currentMode({ ...outputs[0], width: 0, height: 0, refreshRate: 0 }), "1920x1200@60.000Hz", "disabled displays use an advertised mode when current geometry is absent");
assert.equal(draft[1].mode, "3840x2160@59.940Hz", "exact advertised refresh string survives");
assert.equal(model.currentMode({ ...outputs[1], refreshRate: 60 }), "3840x2160@60.00Hz", "59.94 and 60 Hz are not interchangeable in the picker");
assert.deepEqual(plain(model.rect({ ...draft[1], transform: 1 })), { x: 0, y: 0, width: 1440, height: 2560 });
assert.equal(model.parseMode("3840x2160@60;exec"), null);
for (const [key, value] of [["x", NaN], ["y", Infinity], ["x", ""], ["x", 32769], ["x", 1.5], ["scale", 0], ["scale", 4.1], ["scale", "bad"], ["transform", 8], ["mode", "3840x2160@75"]]) {
    const changed = plain(draft); changed[1][key] = value;
    assert.notEqual(model.validate(changed, outputs), "", `${key}=${value} must be rejected`);
    const rect = model.rect(changed[1]);
    assert.ok(Object.values(rect).every(Number.isFinite), "invalid drafts cannot poison canvas geometry");
}
for (const [key, values] of Object.entries({ x: [-32768, 32768, "0"], y: [-32768, 32768], scale: [0.5, 4], transform: [0, 7] })) {
    for (const value of values) assert.equal(model.validate(draft.map(d => ({ ...d, [key]: value })), outputs), "", `${key}=${value} is valid`);
}
const tile = { name: "DP-1", mode: "100x100@60", scale: 1, x: 200, y: 300, enabled: true };
const layout = [{ ...tile, name: "HDMI-A-1" }, tile];
assert.deepEqual(plain(model.snap(layout, "HDMI-A-1", 101, 199, 10)), { x: 100, y: 200 });
assert.deepEqual(plain(model.snap(layout, "HDMI-A-1", 150, 250, 50)), { x: 150, y: 250 }, "threshold is exclusive");
assert.deepEqual(plain(model.snap(layout, "HDMI-A-1", 150, 250, 51)), { x: 200, y: 300 }, "equal distances retain the first edge");
const desktop = [outputs[1]];
assert.notEqual(model.validate([{ ...draft[1], enabled: false }], desktop), "", "last output protected");
assert.equal(model.validate([{ ...draft[0], enabled: false }, draft[1]], outputs), "", "laptop can be disabled with an active external display");
assert.equal(model.validate([{ ...draft[0], enabled: true }, { ...draft[1], enabled: false }], outputs), "", "external display can be disabled with an active laptop");
assert.notEqual(model.validate(draft.map(d => ({ ...d, enabled: false })), outputs), "", "all-off layout rejected");
const mirroredOutputs = outputs.map(o => ({ ...o, disabled: false }));
mirroredOutputs[1].mirrorOf = "0";
const mirrored = model.draft(mirroredOutputs);
assert.equal(mirrored[1].mirror_of, "eDP-1", "compositor IDs resolve to connector identities");
assert.equal(model.validate(mirrored, mirroredOutputs), "", "different physical modes can mirror");
assert.equal(model.payload(mirrored)[1].mirror_of, "eDP-1");
assert.equal(model.mirrorSource({ ...mirroredOutputs[1], mirrorOf: 0 }, mirroredOutputs), "eDP-1");
assert.equal(model.mirrorSource({ ...mirroredOutputs[1], mirrorOf: "none" }, mirroredOutputs), "");
for (const source of ["DP-1", "DP-99", "eDP-1\";evil", false, 0, null]) {
    const invalid = plain(mirrored); invalid[1].mirror_of = source;
    assert.notEqual(model.validate(invalid, mirroredOutputs), "");
}
const cycle = plain(mirrored); cycle[0].mirror_of = "DP-1";
assert.notEqual(model.validate(cycle, mirroredOutputs), "", "mirror cycles are rejected");
const disabledSource = plain(mirrored); disabledSource[0].enabled = false;
assert.notEqual(model.validate(disabledSource, mirroredOutputs), "", "mirrors require an enabled source");
assert.equal(model.mirrorSources(mirrored, "eDP-1").length, 0, "sources cannot create chains");
const extended = model.extend(mirrored, "DP-1");
assert.equal(extended[1].mirror_of, "");
assert.ok(extended[1].x >= model.rect(extended[0]).x + model.rect(extended[0]).width - 0.5, "extend places the screen beside the source");
const sourceOff = model.setEnabled(mirrored, "eDP-1", false);
assert.equal(sourceOff[1].mirror_of, "", "disabling a source promotes its mirrors");
assert.equal(model.validate(sourceOff, mirroredOutputs), "");
// Displays' controller tests own stale configuration/topology rejection, rather
// than prescribing how the model fingerprints a snapshot.
const focus = {};
vm.createContext(focus);
vm.runInContext(fs.readFileSync(require("node:path").join(require("node:path").dirname(process.argv[2]), "DisplayFocusModel.js"), "utf8").replace(/^\.pragma library\s*/m, ""), focus);
const controls = focus.groups().flatMap(group => group.settings);
assert.equal(controls.length, 26);
assert.equal(new Set(controls.map(item => item.key)).size, controls.length);
for (const item of controls) {
    assert.ok(item.title && item.help);
    for (const choice of item.choices) assert.equal(typeof focus.value(item, choice.value), item.boolean ? "boolean" : "number");
    if (!item.choices.length) {
        for (const invalid of ["", " ", "bad", "NaN", "Infinity", -1, item.maximum + 1]) assert.equal(focus.validNumber(item, invalid), false);
        assert.equal(focus.validNumber(item, 0), true);
        assert.equal(focus.validNumber(item, item.maximum), true);
        assert.equal(focus.validNumber(item, 0.5), !item.whole);
    }
}
console.log("display model: modes, geometry, mirroring, last-output safety and 26 focus controls passed");
