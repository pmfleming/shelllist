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
// Daemon-owned normalization is tested in Rust. The frontend consumes opaque
// IDs and typed geometry, even if raw compositor strings disagree.
Object.assign(outputs[0], { supported: true, internal: true, mirror_of: "", current_mode: "1920x1200@60.000Hz", modes: [
    { id: "1920x1200@60.000Hz", width: 1920, height: 1200, rate: 60, size: "1920x1200" }
] });
Object.assign(outputs[1], { supported: true, internal: false, mirror_of: "", current_mode: "3840x2160@59.940Hz", modes: [
    { id: "3840x2160@59.940Hz", width: 3840, height: 2160, rate: 59.94, size: "3840x2160" },
    { id: "3840x2160@60.00Hz", width: 3840, height: 2160, rate: 60, size: "3840x2160" },
    { id: "2560x1440@120.00Hz", width: 2560, height: 1440, rate: 120, size: "2560x1440" }
] });
const draft = model.draft(outputs);
assert.equal(draft[1].mode, "3840x2160@59.940Hz", "exact daemon mode ID survives");
assert.equal(model.modeInfo(outputs[1], "3840x2160@60;exec"), null);
assert.equal(model.outputs({outputs: [{name: "DP-99"}]}).length, 0, "raw legacy records must not be locally normalized");
assert.equal(model.modeInfo({availableModes: ["1920x1200@60"], current_mode: "1920x1200@60"}), null);
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
// Presentation parking keeps every physical screen visible without changing
// draft positions or the geometry of the independent desktops.
const mapDraft = plain(draft);
mapDraft[0].x = 0;
mapDraft.push({ ...mapDraft[1], name: "HDMI-A-1", mirror_of: "DP-1" });
const originalMapDraft = plain(mapDraft);
const tiles = model.canvasValues(mapDraft);
assert.equal(tiles.length, mapDraft.length);
assert.deepEqual(plain(tiles[1]), mapDraft[1]);
assert.ok(tiles[0].x > model.rect(tiles[1]).x + model.rect(tiles[1]).width);
assert.ok(tiles[2].x > model.rect(tiles[0]).x + model.rect(tiles[0]).width);
assert.deepEqual(mapDraft, originalMapDraft, "canvas placement cannot mutate the layout payload");
assert.equal(model.canvasValues([]).length, 0);
const allOff = model.canvasValues(mapDraft.map(o => ({ ...o, enabled: false })));
assert.ok(allOff.every(o => Object.values(model.rect(o)).every(Number.isFinite)));
assert.ok(allOff[1].x > allOff[0].x + model.rect(allOff[0]).width);
const extended = mapDraft.slice(0, 2).map((o, i) => ({ ...o, enabled: true, x: i ? 0 : -1536, y: -200, transform: i }));
assert.deepEqual(plain(model.canvasValues(extended)), extended, "negative positions and rotation retain desktop geometry");
const arranged = plain(draft).map(o => ({ ...o, enabled: true }));
arranged[0].x = 0;
arranged[1].x = 1536;
const expected = { left: [-2560, 0], above: [0, -1440], below: [0, 960], right: [1536, 0] };
for (const [side, [x, y]] of Object.entries(expected)) {
    const candidate = model.placement(arranged, "DP-1", "eDP-1", side);
    assert.equal(candidate.error, "");
    assert.deepEqual([candidate.x, candidate.y], [x, y]);
    const changed = arranged.map(o => o.name === "DP-1" ? { ...o, x, y } : o);
    assert.equal(model.arrangementError(changed, arranged), "");
}
for (const [name, reference, side] of [["missing", "eDP-1", "left"], ["DP-1", "DP-1", "left"], ["DP-1", "missing", "left"], ["DP-1", "eDP-1", "diagonal"]])
    assert.notEqual(model.placement(arranged, name, reference, side).error, "");
assert.notEqual(model.placement(draft, "DP-1", "eDP-1", "left").error, "", "disabled reference rejected");
assert.notEqual(model.placement(mirrored, "DP-1", "eDP-1", "left").error, "", "mirror cannot move independently");
const blocked = [...arranged, { ...arranged[1], name: "HDMI-A-1", x: -2560 }];
assert.match(model.placement(blocked, "DP-1", "eDP-1", "left").error, /HDMI-A-1/);
blocked[2].enabled = false;
assert.equal(model.placement(blocked, "DP-1", "eDP-1", "left").error, "");
blocked[2].enabled = true; blocked[2].mirror_of = "eDP-1";
assert.equal(model.placement(blocked, "DP-1", "eDP-1", "left").error, "");
const negative = arranged.map(o => ({ ...o, x: -32768, y: -32768 }));
assert.match(model.placement(negative, "DP-1", "eDP-1", "left").error, /coordinates/);
assert.match(model.placement(negative, "DP-1", "eDP-1", "above").error, /coordinates/);
const fractional = arranged.map(o => ({ ...o, scale: 1.75, transform: 1, x: -100, y: -200 }));
for (const side of Object.keys(expected)) {
    const candidate = model.placement(fractional, "DP-1", "eDP-1", side);
    assert.equal(candidate.error, "", "rounded rotated fractional dimensions touch without overlap");
    assert.ok(Number.isInteger(candidate.x) && Number.isInteger(candidate.y));
    assert.equal(model.overlaps(candidate, model.placementRect(fractional[0])), false);
}
const oldOverlap = arranged.map(o => ({ ...o, x: 0 }));
assert.equal(model.arrangementError(oldOverlap, oldOverlap), "", "observed layouts are not silently repaired");
assert.notEqual(model.arrangementError(oldOverlap, arranged), "", "new overlaps block Preview");
const resized = arranged.map(o => o.name === "eDP-1" ? { ...o, scale: 1 } : o);
assert.match(model.arrangementError(resized, arranged), /overlaps/);
assert.equal(model.dropTarget(arranged, "DP-1", 500, -500, 20, null, 6), null);
const top = model.dropTarget(arranged, "DP-1", 768, 0, 24, null, 6);
assert.equal(top.reference, "eDP-1"); assert.equal(top.side, "above");
const retained = model.dropTarget(arranged, "DP-1", 1, 4, 24, top, 6);
assert.equal(retained.side, "above", "corner dead band retains the current side");
assert.equal(model.dropTarget(arranged, "DP-1", 0, 20, 24, retained, 6).side, "left");
assert.equal(model.dropTarget(draft, "DP-1", 0, 0, 24, null, 6), null, "disabled screens cannot be drop targets");
const dragExtent = model.dragBounds(arranged, "DP-1");
for (const side of Object.keys(expected)) {
    const candidate = model.placement(arranged, "DP-1", "eDP-1", side);
    assert.ok(candidate.x >= dragExtent.x && candidate.y >= dragExtent.y);
    assert.ok(candidate.x + candidate.width <= dragExtent.x + dragExtent.width);
    assert.ok(candidate.y + candidate.height <= dragExtent.y + dragExtent.height);
}
// Native Displays tests own enable/extend/promotion, stale identities, focus
// setting payloads and acknowledgement. Do not duplicate their UI catalogues.
console.log("display model: normalized modes, relative placement, collision/edge geometry and unsafe-layout rejection passed");
