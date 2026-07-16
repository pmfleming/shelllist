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

console.log(`IP validation: ${checks} checks passed`);
