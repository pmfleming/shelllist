#!/usr/bin/env node
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
assert.ok(process.argv[2], "usage: check-display-model.js <DisplayModel.js>");
const model = {};
vm.createContext(model);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*/m, ""), model);
const plain = value => JSON.parse(JSON.stringify(value));
const outputs = [
    { id: 0, name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, scale: 1.25, x: -1536, y: 0, transform: 0, disabled: true, availableModes: ["1920x1200@60.000Hz"] },
    { id: 1, name: "DP-1", description: "Desk", width: 3840, height: 2160, refreshRate: 59.94, scale: 1.5, x: 0, y: 0, transform: 0, disabled: false, availableModes: ["3840x2160@59.940Hz", "3840x2160@60.00Hz", "2560x1440@120.00Hz"] }
];
const draft = model.draft(outputs);
assert.equal(model.currentMode({ ...outputs[0], width: 0, height: 0, refreshRate: 0 }), "1920x1200@60.000Hz", "disabled displays use an advertised mode when current geometry is absent");
assert.equal(draft[1].mode, "3840x2160@59.940Hz", "exact advertised refresh string survives");
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
// Rejection matters, not the wording or precedence of simultaneous field errors.
assert.notEqual(model.validate([], []), "", "an empty layout is unsafe");
assert.notEqual(model.validate([draft[0], draft[0]], outputs), "", "duplicate identities are rejected");
assert.notEqual(model.validate(draft.map(d => ({ ...d, enabled: false })), outputs), "", "all-off layout rejected");
const mirroredOutputs = outputs.map(o => ({ ...o, disabled: false }));
mirroredOutputs[1].mirrorOf = "0";
const mirrored = model.draft(mirroredOutputs);
for (const source of ["DP-1", "DP-99", "eDP-1\";evil", false, 0, null]) {
    const invalid = plain(mirrored); invalid[1].mirror_of = source;
    assert.notEqual(model.validate(invalid, mirroredOutputs), "");
}
const cycle = plain(mirrored); cycle[0].mirror_of = "DP-1";
assert.notEqual(model.validate(cycle, mirroredOutputs), "", "mirror cycles are rejected");
const disabledSource = plain(mirrored); disabledSource[0].enabled = false;
assert.notEqual(model.validate(disabledSource, mirroredOutputs), "", "mirrors require an enabled source");
// Native Displays tests own enable/extend/promotion, stale identities, focus
// setting payloads and acknowledgement. Do not duplicate their UI catalogues.
console.log("display model: exact modes, finite geometry and unsafe-layout rejection passed");
