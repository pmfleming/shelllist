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

equal(context.resumeGenerationAdvanced(-1, 3), false, "initial snapshot is a baseline");
equal(context.resumeGenerationAdvanced(0, 1), true, "short sleep has an explicit resume event");
equal(context.resumeGenerationAdvanced(1, 1), false, "repeated telemetry and wall-clock jumps do not rebuild");
equal(context.resumeGenerationAdvanced(1, 4), true, "coalesced events still recover");
equal(context.resumeGenerationAdvanced(4, 0), false, "daemon restart resets the baseline");
equal(context.resumeGenerationAdvanced(0, 1), true, "resume after daemon restart");
equal(context.resumeGenerationAdvanced(0, NaN), false, "older daemon / unavailable generation");

console.log("bar surface recovery: resume detection passed");
