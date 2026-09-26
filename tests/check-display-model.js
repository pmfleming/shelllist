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
assert.equal(draft[0].enabled, true, "preview safety does not copy the observed disabled laptop");
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
assert.notEqual(model.validate([{ ...draft[0], enabled: false }, draft[1]], outputs), "", "internal fallback protected");
// Displays' controller tests own stale configuration/topology rejection, rather
// than prescribing how the model fingerprints a snapshot.
console.log("display model: exact modes, mixed-DPI/rotation geometry, invalid inputs and fallback validation passed");
