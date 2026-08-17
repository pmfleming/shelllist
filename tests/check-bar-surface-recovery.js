#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

function equal(actual, expected, message) {
    if (JSON.stringify(actual) !== JSON.stringify(expected))
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

equal(context.screenSignature([
    { name: "DP-2", width: 2560, height: 1440 },
    { name: "eDP-1", width: 1920, height: 1080 }
]), "DP-2:2560x1440|eDP-1:1920x1080", "stable sorted screen signature");
equal(context.screenSignature([{ name: "", width: 1, height: 1 }]), "",
    "temporary unnamed screens are ignored");
equal(context.heartbeatIndicatesResume(1000, 3000, 2000, 6000), false,
    "normal heartbeat");
equal(context.heartbeatIndicatesResume(1000, 10001, 2000, 6000), true,
    "suspend gap");
equal(context.heartbeatIndicatesResume(0, 10000, 2000, 6000), false,
    "uninitialized heartbeat");

console.log("bar surface recovery: screen and resume detection passed");
