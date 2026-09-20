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
assert.equal(outputs[0].disabled, true, "normalization must not mutate observed state");
assert.equal(draft[1].mode, "3840x2160@59.940Hz", "exact advertised refresh string survives");
assert.equal(model.validate(draft, outputs), "");
assert.equal(model.currentMode({ ...outputs[1], refreshRate: 60 }), "3840x2160@60.00Hz", "59.94 and 60 Hz are not interchangeable in the picker");
assert.deepEqual(plain(model.rect(draft[1])), { x: 0, y: 0, width: 2560, height: 1440 });
assert.deepEqual(plain(model.rect({ ...draft[1], transform: 1 })), { x: 0, y: 0, width: 1440, height: 2560 });
assert.deepEqual(plain(model.rect({ ...draft[1], transform: 5 })), { x: 0, y: 0, width: 1440, height: 2560 });
assert.deepEqual(plain(model.bounds(draft)), { x: -1536, y: 0, width: 4096, height: 1440 });
assert.equal(model.title(outputs[1]), "Desk");
assert.equal(model.rates(outputs[1], draft[1].mode).length, 2);
assert.equal(model.resolutions(outputs[1]).length, 2);
assert.equal(model.parseMode("3840x2160@NaN"), null);
assert.equal(model.parseMode("0x2160@60"), null);
assert.equal(model.parseMode("3840x2160@60;exec"), null);
assert.equal(model.parseMode("99999999999999999999x2160@60"), null);
for (const [key, value] of [["x", NaN], ["y", Infinity], ["x", ""], ["x", 32769], ["x", 1.5], ["scale", 0], ["scale", 4.1], ["scale", "bad"], ["transform", 8], ["mode", "3840x2160@75"]]) {
    const changed = plain(draft); changed[1][key] = value;
    assert.notEqual(model.validate(changed, outputs), "", `${key}=${value} must be rejected`);
    const rect = model.rect(changed[1]);
    assert.ok(Object.values(rect).every(Number.isFinite), "invalid drafts cannot poison canvas geometry");
}
const desktop = [outputs[1]];
assert.notEqual(model.validate([{ ...draft[1], enabled: false }], desktop), "", "last output protected");
assert.notEqual(model.validate([{ ...draft[0], enabled: false }, draft[1]], outputs), "", "internal fallback protected");
assert.notEqual(model.validate(draft, [outputs[0]]), "", "removed output invalidates complete draft");
assert.notEqual(model.validate([draft[0], draft[0]], outputs), "", "duplicate connectors invalid");
assert.notEqual(model.topology(outputs), model.topology([{ ...outputs[0], id: 99 }, outputs[1]]));
assert.notEqual(model.fingerprint(outputs), model.fingerprint([outputs[0], { ...outputs[1], x: 99 }]));
assert.deepEqual(plain(model.snap(draft, "DP-1", 8, 7, 10)), { x: 0, y: 0 });
assert.deepEqual(plain(model.snap(draft, "DP-1", 8, 7, 0)), { x: 8, y: 7 });
assert.deepEqual(plain(model.adjacent(draft[1], draft[0], "below")), { x: -1536, y: 960 });
assert.deepEqual(plain(model.adjacent(draft[1], draft[0], "left")), { x: -4096, y: 0 });
const payload = model.payload(draft);
assert.deepEqual(Object.keys(payload[0]).sort(), ["enabled", "mode", "name", "scale", "transform", "x", "y"]);
assert.equal(model.outputs({ outputs: [...outputs, { name: "HEADLESS-1" }] }).length, 2);
console.log("display model: exact modes, mixed-DPI/rotation geometry, snapping, topology and fallback validation passed");
