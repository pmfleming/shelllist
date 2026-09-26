#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const presentationPaths = process.argv.slice(2, 6);
if (presentationPaths.length !== 4)
    throw new Error("usage: check-bar-presentation.js <workspace.js> <media.js> <osd.js> <status.js> [Duration.js]");
const sources = presentationPaths.map(file => fs.readFileSync(file, "utf8")
    .replace(/^\.pragma library\s*$/m, ""));
const durationImport = sources.join("\n").match(/^\.import\s+"([^"]+)"\s+as\s+Duration\s*$/m);
const Duration = {};
vm.createContext(Duration);
vm.runInContext(fs.readFileSync(process.argv[6]
    || path.resolve(path.dirname(presentationPaths[3]), durationImport[1]), "utf8")
    .replace(/^\.pragma library\s*$/m, ""), Duration);
const context = { Duration, Qt: { formatDateTime: (_date, format) => format } };
vm.createContext(context);
for (const source of sources)
    vm.runInContext(source.replace(/^\.import.*$/m, ""), context);

function equal(actual, expected, message) {
    if (JSON.stringify(actual) !== JSON.stringify(expected))
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

equal(context.mediaPositionPercent({
    length_us: 240000000, position_us: 60000000, playback_status: "playing",
    position_observed_at_unix_ms: 1000, playback_rate: 1
}, 61000), 50, "media progress advances from observed position");
equal(context.mediaPositionPercent({
    length_us: 100, position_us: 90, playback_status: "playing",
    position_observed_at_unix_ms: 0, playback_rate: 2
}, 1000), 100, "media progress is bounded");
equal(context.inputOsd({ input_muted: true, source_description: "Microphone" }).progressVisible,
    false, "mute does not invent a volume measurement");
// Brightness OSD acknowledgement and all failure routes are exercised through
// BarController and the actual surface in tst_bar_osd_responsiveness.qml.

// Keep agenda reachability without pinning the responsive module catalogue.
equal(context.activityModule({ available: false }, { count: 0 }).visible, true,
    "agenda remains reachable without a calendar provider");

console.log("bar presentation: OSD policy, progress and agenda reachability passed");
