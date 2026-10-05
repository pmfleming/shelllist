#!/usr/bin/env node
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const model = {};
vm.createContext(model);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*/m, ""), model);
const plain = value => JSON.parse(JSON.stringify(value));
// Consume typed daemon data, not legacy compositor strings. Qt covers opaque
// mode IDs, draft-only UI edits, stale identities and preview/revert ownership.
const outputs = [
    { id: 0, name: "eDP-1", supported: true, internal: true, disabled: true,
      width: 1920, height: 1200, refreshRate: 60, scale: 1.25, x: -1536, y: 0,
      transform: 0, mirror_of: "", current_mode: "laptop-mode",
      modes: [{ id: "laptop-mode", width: 1920, height: 1200, rate: 60, size: "1920x1200" }] },
    { id: 1, name: "DP-1", supported: true, internal: false, disabled: false,
      width: 3840, height: 2160, refreshRate: 59.94, scale: 1.5, x: 0, y: 0,
      transform: 0, mirror_of: "", current_mode: "desk-mode",
      modes: [{ id: "desk-mode", width: 3840, height: 2160, rate: 59.94, size: "3840x2160" }] }
];
const draft = model.draft(outputs);
for (const [key, value] of [["x", NaN], ["y", Infinity], ["x", ""], ["x", 32769], ["x", 1.5], ["scale", 0], ["scale", 4.1], ["scale", "bad"], ["transform", 8], ["mode", "unknown;exec"]]) {
    const changed = plain(draft); changed[1][key] = value;
    assert.notEqual(model.validate(changed, outputs), "", `${key}=${value} must be rejected`);
}
for (const [key, values] of Object.entries({ x: [-32768, 32768, "0"], y: [-32768, 32768], scale: [0.5, 4], transform: [0, 7] })) {
    for (const value of values)
        assert.equal(model.validate(draft.map(d => ({ ...d, [key]: value })), outputs), "", `${key}=${value} is valid`);
}
assert.notEqual(model.validate([], []), "", "an empty layout is unsafe");
assert.notEqual(model.validate([draft[1], draft[1]], outputs), "", "duplicate identities are rejected");
assert.notEqual(model.validate(draft.map(d => ({ ...d, enabled: false })), outputs), "", "all-off layout rejected");
const mirroredOutputs = outputs.map(o => ({ ...o, disabled: false }));
mirroredOutputs[1].mirror_of = "eDP-1";
const mirrored = model.draft(mirroredOutputs);
for (const source of ["DP-1", "DP-99", "eDP-1\";evil", false, 0, null]) {
    const invalid = plain(mirrored); invalid[1].mirror_of = source;
    assert.notEqual(model.validate(invalid, mirroredOutputs), "");
}
const cycle = plain(mirrored); cycle[0].mirror_of = "DP-1";
assert.notEqual(model.validate(cycle, mirroredOutputs), "", "mirror cycles are rejected");
const disabledSource = plain(mirrored); disabledSource[0].enabled = false;
assert.notEqual(model.validate(disabledSource, mirroredOutputs), "", "mirrors require an enabled source");

// Direction arithmetic belongs here; Qt needs representative button/drag routes,
// not another complete matrix of these same coordinates.
const arranged = plain(draft).map(o => ({ ...o, enabled: true }));
arranged[0].x = 0;
arranged[1].x = 1536;
const expected = { left: [-2560, 0], above: [0, -1440], below: [0, 960], right: [1536, 0] };
for (const [side, coordinates] of Object.entries(expected)) {
    const candidate = model.placement(arranged, "DP-1", "eDP-1", side);
    assert.deepEqual([candidate.x, candidate.y], coordinates);
}
const fractional = arranged.map(o => ({ ...o, scale: 1.75, transform: 1, x: -100, y: -200 }));
for (const side of Object.keys(expected)) {
    const candidate = model.placement(fractional, "DP-1", "eDP-1", side);
    assert.equal(candidate.error, "", "rounded rotated fractional dimensions touch without overlap");
}
const tiles = [0, 100, 1000].map((x, i) => ({ name: String(i), enabled: true, x, y: 0, width: 100, height: 100, scale: 1 }));
for (const [x, y, previous, expected] of [
    [-10, 50, null, ["0", "left"]], [50, -10, null, ["0", "above"]],
    [50, 110, null, ["0", "below"]], [210, 50, null, ["1", "right"]],
    [101, 50, {reference: "0", side: "right"}, ["1", "left"]],
    [1, 1, {reference: "0", side: "above"}, ["0", "above"]], [500, 500, null, null]
]) {
    const target = model.dropTarget(tiles, "2", x, y, 30, previous, 10);
    assert.deepEqual(target ? [target.reference, target.side] : null, expected);
}
console.log("display model: numeric/layout safety, placement, edge targets and hysteresis passed");
