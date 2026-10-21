#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");
const assert = require("assert/strict");
const [validationPath, editPath] = process.argv.slice(2);
if (!validationPath || !editPath) throw new Error("usage: check-ip-control.js <IpValidation.js> <IpEdit.js>");
function load(path, globals = {}) {
    const context = vm.createContext(globals);
    vm.runInContext(fs.readFileSync(path, "utf8").replace(/^\.(pragma|import).*\n/gm, ""), context, {filename: path});
    return context;
}
const validation = load(validationPath);
const edit = load(editPath, {Validation: validation});
const v4 = {family: "ipv4", mode: "address", subnetNotation: "prefix", allowEmpty: true};
const v4p = {...v4, mode: "addressWithSubnet", allowEmpty: false};
const v4m = {...v4p, subnetNotation: "netmask"};
const v6 = {...v4, family: "ipv6"};
const v6p = {...v4p, family: "ipv6"};
let checks = 0;
function equal(actual, expected, label) { checks++; assert.equal(actual, expected, label); }
function state(text, config, expected) { equal(edit.inspect(text, config).state, expected, JSON.stringify(text)); }
for (const config of [v4p, v4m]) {
    for (let prefix = 0; prefix <= 32; prefix++) {
        const mask = edit.prefixMask(prefix);
        equal(edit.maskPrefix(mask), prefix, "every mask/prefix round trip");
        const value = edit.inspect("192.168.178.119/" + mask, config);
        equal(value.valid, true);
        equal(value.prefixLength, prefix);
        equal(value.address, "192.168.178.119", "host bits must survive");
        equal(value.text, "192.168.178.119/" + (config === v4m ? mask : prefix));
    }
}
equal(edit.prefixMask(23), "255.255.254.0");
for (const value of ["255.0.255.0", "0.0.0.1", "255.255.255.256", "255.255.255", "-1.0.0.0"]) {
    equal(edit.maskPrefix(value), -1);
    state("192.0.2.1/" + value, v4m, value === "255.255.255" ? 1 : 0);
}
for (const [value, expected] of [
    ["", 1], [".../", 1], ["10.0.0.1/", 1], ["10..0.1/24", 1], ["/24", 1],
    ["0.0.0.0/0", 2], ["255.255.255.255/32", 2], ["10.0.0.1/33", 0],
    ["999.0.0.1/24", 0], ["10.0.0.1/3200", 0], ["10.0.0.1/24/1", 0],
    ["10.0.0.1/24 ", 0], ["10.0.0.1/24".padEnd(32767), 0]
]) state(value, v4p, expected);
for (const config of [v4, v6]) state("", config, 2);
state("...", v4, 2);
state("....", v4, 0);
state("...", v6, 0);
state("10.0.0.1/24", v4, 0);
state("::1/128", v6, 0);
state("/", {...v6p, allowEmpty: true}, 2);
state("::/", {...v6p, allowEmpty: true}, 1);
state(".../...", {...v4m, allowEmpty: true}, 2);
// Invalid beats incomplete in either half; optional permits only a wholly empty pair.
for (const [value, expected] of [
    ["999..0.1/", 0], ["10..0.1/33", 0], ["10..0.1/255.0.255.0", 0],
    ["10.0.0.1/255.255.", 1], [".../24", 1], [".../.../", 0]
]) state(value, {...v4m, allowEmpty: true}, expected);
const invalidMask = edit.inspect("10.0.0.1/255.0.255.0", v4m);
equal(invalidMask.prefixLength, -1);
equal(invalidMask.text, "10.0.0.1/255.0.255.0", "invalid source notation is retained");
for (const value of ["::", "::1", "2001:DB8::1", "1:2:3:4:5:6:7:8", "::ffff:192.0.2.1", "1:2:3:4:5:6:192.0.2.1"]) {
    state(value, v6, 2);
    for (const prefix of [0, 64, 128]) state(value + "/" + prefix, v6p, 2);
}
for (const value of ["2001:::1", "1::2::3", "12345::1", "1:2:3:4:5:6:7:8:9", "::192.0.2.1:1", "1:2:3:4:5:6:7:192.0.2.1", "fe80::1%eth0", "[::1]:80", "::1/129", "::1/ffff:ffff::"]) state(value, v6p, 0);
state("1:2:3:4:5:6:7/64", v6p, 1);
equal(edit.inspect("192.000.002.001/024", v4p).text, "192.0.2.1/24");
equal(edit.inspect("::FFFF:192.000.002.001/128", v6p).text, "::ffff:192.0.2.1/128");
for (const [value, config, result] of [
    ["192.168.999.1/33", v4p, "192.168.999.1/33"],
    ["192.0.2.1 / 255.0.255.0", v4p, "192.0.2.1/255.0.255.0"],
    ["192.0.2.1", v4m, "192.0.2.1/..."],
    ["2001:db8::1", v6p, "2001:db8::1/"],
    ["2001:db8::1/129", v6p, "2001:db8::1/129"],
    ["192.0.2.1/24", v4, null], ["192.0.2.1/24/1", v4p, null],
    ["192.0.2.1 / 24 ", v4p, null], ["192.0.2.1\t/24", v4p, null],
    ["192.0.2.1" + " ".repeat(32767) + "/24", v4p, null],
    ["::1/64", v4p, null], ["192.0.2.1/24", v6p, null],
    ["::1%lo/128", v6p, null], ["[::1]/128", v6p, null], ["2001:::1/64", v6p, null]
]) equal(edit.fullPaste(value, config), result, value);
function position(text, cursor, anchor = cursor, autoSlot = -1) { return {text, cursor, anchor, autoSlot}; }
let draft = position(edit.prepare("", v4p), 0);
for (const ch of "19216817811924") {
    draft = edit.replace(draft, v4p, draft.cursor, draft.anchor, ch, false, true);
    assert(draft);
}
equal(draft.text, "192.168.178.119/24");
// Inserting into an existing slot cannot enable fresh-slot auto advance.
let changed = edit.replace(position("19.168.1.2/24", 2), v4p, 2, 2, "2", false, true);
equal(changed.text, "192.168.1.2/24");
equal(changed.cursor, 3);
changed = edit.replace(position("192.168.1.2/24", 0, 3), v4p, 0, 3, "256", false, true);
equal(changed.text, "256.168.1.2/24");
state(changed.text, v4p, 0);
changed = edit.replace(position("10.0.0.1/24", 3), v4p, 2, 3, "", false, true);
equal(changed.text, "1.0.0.1/24", "backspace crosses a fixed dot");
changed = edit.replace(position("10.0.0.1/24", 2), v4p, 2, 3, "", false, false);
equal(changed.text, "10..0.1/24", "delete crosses a fixed dot");
for (const [text, config, start, end, backwards, expected] of [
    ["10.../24", v4p, 5, 6, true, "1.../24"],
    ["10.../24", v4p, 2, 3, false, "10.../4"],
    ["::1/64", v6p, 3, 4, true, "::/64"],
    ["::1/64", v6p, 3, 4, false, "::1/4"]
]) equal(edit.replace(position(text, start, end), config, start, end, "", false, backwards).text, expected, "separator deletion skips empty slots");
for (const backwards of [true, false]) equal(edit.replace(position("...", 0, 1), v4, 0, 1, "", false, backwards), null);
changed = edit.replace(position("10.0.0.1/24", 0, 11), v4p, 0, 11, "", false, true);
equal(changed.text, ".../", "cut/delete preserves structural separators");
equal(edit.replace(position("192.0.2.1", 0, 9), v4, 0, 9, "g", false, true), null);
equal(edit.replace(position("192.0.2.1", 0, 3), v4, 0, 3, "1234", true, true), null);
// A native committed multi-character insertion uses local selection semantics,
// not full-value clipboard replacement. QML/IME use this same entry point.
changed = edit.nativeEdit(position("2001:db8::1/64", 5, 8), v6p, "2001:ABCD::1/64", false, true);
equal(changed.text, "2001:ABCD::1/64");
equal(edit.nativeEdit(position("2001:db8::1/64", 5, 8), v6p, "2001:zz::1/64", false, true), null);
// Unexpected source suffixes cannot disappear as a side effect of a local edit.
equal(edit.replace(position("192.0.2.1/24", 1), v4, 1, 1, "1", false, true), null);
equal(edit.replace(position("192.0.2.1/24", 0, 12), v4, 0, 12, "", false, true).text, "...");
for (const config of [{...v6p, subnetNotation: "netmask"}, {...v4, family: "unknown"}, {...v4, mode: "unknown"}]) {
    state("", config, 0);
    equal(edit.fullPaste("192.0.2.1", config), null);
}
console.log(`IP control: ${checks} checks passed`);
