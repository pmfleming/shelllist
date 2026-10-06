#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const validatorPath = process.argv[2];
if (!validatorPath)
    throw new Error("usage: check-ip-validation.js <IpValidation.js>");

const source = fs.readFileSync(validatorPath, "utf8").replace(/^\.pragma library\s*/, "");
const validation = {};
vm.createContext(validation);
vm.runInContext(source, validation, { filename: validatorPath });

const { Invalid, Intermediate, Acceptable } = validation;
let checks = 0;

function expectState(label, actual, expected) {
    ++checks;
    if (actual !== expected)
        throw new Error(`${label}: expected state ${expected}, got ${actual}`);
}

function addressCases(family, cases) {
    for (const [value, expected] of cases)
        expectState(`${family} address ${JSON.stringify(value)}`, validation.addressState(value, family), expected);
}

addressCases("ipv4", [
    ["", Intermediate],
    ["1", Intermediate],
    ["192.168.1.", Intermediate],
    ["192.168.1.20", Acceptable],
    ["0.0.0.0", Acceptable],
    ["255.255.255.255", Acceptable],
    ["256.1.1.1", Invalid],
    ["1..2.3", Invalid],
    ["1.2.3.4.5", Invalid],
    ["host.local", Invalid]
]);

addressCases("ipv6", [
    ["", Intermediate],
    [":", Intermediate],
    ["2001:db8:", Intermediate],
    ["2001:db8::", Acceptable],
    ["::", Acceptable],
    ["::1", Acceptable],
    ["1:2:3:4:5:6:7:8", Acceptable],
    ["1:2:3:4:5:6:7", Intermediate],
    ["::ffff:192.168.", Intermediate],
    ["::ffff:192.168.1.1", Acceptable],
    ["1:2:3:4:5:6:192.0.2.1", Acceptable],
    ["1:::2", Invalid],
    ["1::2::3", Invalid],
    ["12345::1", Invalid],
    ["1:2:3:4:5:6:7:8:", Invalid],
    ["1:2:3:4:5:6:7:8:9", Invalid],
    ["fe80::1%wlan0", Invalid]
]);

const listCases = [
    ["", "ipv4", true, Acceptable],
    ["", "ipv4", false, Intermediate],
    ["1.1.1.1", "ipv4", false, Acceptable],
    ["1.1.1.1, 8.8.8.8", "ipv4", false, Acceptable],
    ["1.1.1.1,", "ipv4", false, Intermediate],
    ["1.1.1.1, 8.8", "ipv4", false, Intermediate],
    ["1.1, 8.8.8.8", "ipv4", false, Invalid],
    ["1.1.1.1,,8.8.8.8", "ipv4", false, Invalid],
    ["2001:4860:4860::8888, 2606:4700:4700::1111", "ipv6", false, Acceptable]
];
for (const [value, family, allowEmpty, expected] of listCases) {
    expectState(
        `${family} list ${JSON.stringify(value)}`,
        validation.addressInputState(value, family, true, allowEmpty),
        expected
    );
}

const prefixCases = [
    ["", "ipv4", false, Intermediate],
    ["", "ipv4", true, Acceptable],
    ["0", "ipv4", false, Acceptable],
    ["32", "ipv4", false, Acceptable],
    ["33", "ipv4", false, Invalid],
    ["128", "ipv6", false, Acceptable],
    ["129", "ipv6", false, Invalid],
    ["abc", "ipv6", false, Invalid]
];
for (const [value, family, allowEmpty, expected] of prefixCases) {
    expectState(
        `${family} prefix ${JSON.stringify(value)}`,
        validation.prefixState(value, family, allowEmpty),
        expected
    );
}

for (const [value, family, multiple, expected] of [
    ["192.168.100.100/24", "ipv4", false, Invalid],
    ["1.1.1.1\n8.8.8.8", "ipv4", true, Acceptable],
    ["2001:db8::\n::1", "ipv6", true, Acceptable],
    ["1.1.1.1,".repeat(65), "ipv4", true, Invalid],
    ["1.1.1.1" + " ".repeat(validation.MaximumEditingLength), "ipv4", false, Invalid]
]) expectState("untruncated input / list limit", validation.addressInputState(value, family, multiple, false), expected);
expectState("prefix buffer boundary", validation.prefixState("24" + " ".repeat(validation.MaximumEditingLength), "ipv4", false), Invalid);
for (const [value, family, multiple, prefix, key] of [
    ["192.168.100.100/24", "ipv4", false, false, "cidr"],
    ["fe80::1%wlan0", "ipv6", false, false, "zone"],
    ["192.168.300.20", "ipv4", false, false, "octet"],
    ["1.1.1.1,", "ipv4", true, false, "empty-list-item"],
    ["129", "ipv6", false, true, "prefix"]
]) {
    ++checks;
    if (validation.issue(value, family, multiple, false, prefix).key !== key)
        throw new Error("incorrect validation reason for " + value);
}
for (const [input, index, octet] of [
    ["1.1.1.1, 192.300.400.1, 999.1.1.1", 2, 2],
    ["1.1.1.1 bad 999.1.1.1", 2, undefined],
    ["255.255.255.255, 1.2.3.999", 2, 4]
]) {
    const issue = validation.issue(input, "ipv4", true, false, false);
    expectState("first invalid address index", issue.index, index);
    expectState("first overflowing octet only", issue.octet, octet);
}
console.log(`IP validation: ${checks} checks passed`);
