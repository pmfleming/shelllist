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

// Monitor routing, not the icon assigned to each personal workspace.
equal(context.workspaceIds({ workspaces: [
    { id: 8, monitor: "eDP-1" }, { id: 7, monitor: "DP-1" }, { id: 3, monitor: "eDP-1" }
] }, "eDP-1"), [1, 2, 3, 4, 5, 8], "persistent and dynamic workspaces");
equal(context.activeWindowFor({ focused_monitor: "eDP-1", active_window: { title: "Terminal" } }, "DP-1"),
    null, "active window is hidden on other monitors");
const mediaPlayers = {
    active_player: "browser",
    players: [{ id: "browser", title: "Podcast" }, { id: "spotify", title: "Music" }]
};
equal(context.playerFor(mediaPlayers).id, "browser", "daemon-selected media player");
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
equal(context.domainOsd({ media: "media" }, "media",
    { available: true, active_player: "player", players: [{ id: "player", title: "Old" }] },
    { available: true, active_player: "player", players: [{ id: "player", title: "New" }] }),
    null, "media changes do not produce an OSD");

equal(context.updateModule({ available: true, ready: false, jobs: [{ name: "system", status: "running", phase: "building" }] }).visible,
    true, "running update jobs are visible before a candidate is ready");
const interruptedUpdate = context.updateModule({ available: true, jobs: [{ name: "system", status: "interrupted", phase: "staging", error: "Worker stopped" }] });
equal(interruptedUpdate.tone, "warning", "interrupted update jobs warn rather than appearing successful");
equal(interruptedUpdate.tooltip.includes("Worker stopped"), true, "update errors remain inspectable");
equal(context.updateModule({ available: true, jobs: [{ name: "system", status: "completed", phase: "skipped" }] }).visible,
    false, "harmless skipped jobs do not claim an available update");

const modules = context.statusModules({
    activity: { available: true, incomplete_todo_count: 1, next_event: null },
    network: { active: false }, updates: { available: true, ready: true },
    bluetooth: { powered: true, allDevices: [] },
    audio: { available: true, muted: false, volume_percent: 50 },
    brightness: { available: true, percent: 70 },
    battery: { available: true, percentage: 80 },
    powerProfile: { available: true, profile: "balanced", driver: "test", profiles: [
        { name: "power-saver" }, { name: "balanced" }, { name: "performance" }
    ] },
    notifications: { count: 2, dnd: false },
    timezone: { available: true, city: "Taipei", abbreviation: "CST", utc_offset_seconds: 28800 }
}, new Date(0));
// Keep reachability, not a mirror of the action-ID table or module order.
equal(context.activityModule({ available: false }, { count: 0 }).visible, true,
    "agenda remains reachable without a calendar provider");
const narrow = context.visibleStatusModules(modules, context.layoutDensity(600)).map(item => item.id);
equal(["network", "battery", "activity", "clock"].every(id => narrow.includes(id)), true,
    "essential actions survive a narrow screen");

console.log("bar presentation: monitor routing, OSD policy, progress and essential actions passed");
