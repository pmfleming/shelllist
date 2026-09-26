#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const presentationPaths = process.argv.slice(2, 6);
if (presentationPaths.length !== 4)
    throw new Error("usage: check-bar-presentation.js <workspace.js> <media.js> <osd.js> <status.js> [Duration.js] [BarIndicators.js]");
function load(file, imports = {}) {
    const context = vm.createContext(imports);
    vm.runInContext(fs.readFileSync(file, "utf8").replace(/^\.(pragma|import).*$/gm, ""), context, { filename: file });
    return context;
}
const Duration = load(process.argv[6] || path.resolve(path.dirname(presentationPaths[3]), "../Core/Duration.js"));
const Indicators = load(process.argv[7] || path.resolve(path.dirname(presentationPaths[3]), "BarIndicators.js"));
// Separate realms matter: loading all files into one silently lets a module use
// another module's private functions, masking missing imports and clones.
const modules = presentationPaths.map(file => load(file, { Duration, Indicators, Qt: { formatDateTime: (_date, format) => format } }));
const [, media, osd, status] = modules;
function equal(actual, expected, message) {
    if (JSON.stringify(actual) !== JSON.stringify(expected))
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

for (const [value, percent, icon] of [[-1, 0, ""], ["33", 33, ""], [34, 34, ""], [66, 66, ""],
    [67, 67, ""], [150, 100, ""], [Infinity, 100, ""], ["invalid", 0, ""], [null, 0, ""]]) {
    const audio = { available: true, volume_percent: value };
    equal([osd.outputOsd(audio).percent, osd.outputOsd(audio).icon, status.audioModule(audio).text],
        [percent, icon, icon], "audio bounds and thresholds agree between OSD and bar");
    equal(osd.brightnessOsd({ percent: value }).percent, percent, "brightness shares bounds");
    equal(osd.keyboardBacklightOsd(value).percent, percent, "keyboard backlight shares bounds");
}
for (const audio of [null, {}, { available: false, volume_percent: 100 }, { available: true, muted: true, volume_percent: 100 }])
    equal([osd.outputOsd(audio).icon, status.audioModule(audio).text], ["󰝟", "󰝟"], "unavailable/muted audio");
for (const [profile, icon] of [["power-saver", ""], ["balanced", ""], ["performance", ""], ["unknown", ""]])
    equal([osd.powerProfileOsd({ profile }).icon, status.powerModule({ profile }).text], [icon, icon], "power glyphs agree");

equal(media.mediaPositionPercent({
    length_us: 240000000, position_us: 60000000, playback_status: "playing",
    position_observed_at_unix_ms: 1000, playback_rate: 1
}, 61000), 50, "media progress advances from observed position");
equal(media.mediaPositionPercent({
    length_us: 100, position_us: 90, playback_status: "playing",
    position_observed_at_unix_ms: 0, playback_rate: 2
}, 1000), 100, "media progress is bounded");
equal(osd.inputOsd({ input_muted: true, source_description: "Microphone" }).progressVisible,
    false, "mute does not invent a volume measurement");
// Brightness OSD acknowledgement and all failure routes are exercised through
// BarController and the actual surface in tst_bar_osd_responsiveness.qml.
equal(status.activityModule({ available: false }, { count: 0 }).visible, true,
    "agenda remains reachable without a calendar provider");

console.log("bar presentation: isolated modules, shared indicators, progress and agenda reachability passed");
