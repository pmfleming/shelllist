#!/usr/bin/env node
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, "");
const context = { Qt: { formatDateTime: (_date, format) => format } };
vm.createContext(context);
vm.runInContext(source, context);

function equal(actual, expected, message) {
    if (JSON.stringify(actual) !== JSON.stringify(expected))
        throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

equal(context.workspaceIds({ workspaces: [
    { id: 8, monitor: "eDP-1" }, { id: 7, monitor: "DP-1" }, { id: 3, monitor: "eDP-1" }
] }, "eDP-1"), [1, 2, 3, 4, 5, 8], "persistent and dynamic workspaces");
equal(context.activeWorkspaceId({ monitors: [
    { name: "eDP-1", active_workspace_id: 3 }
] }, "eDP-1"), 3, "monitor-local active workspace");
equal(context.activeWindowFor({ focused_monitor: "eDP-1", active_window: { title: "Terminal" } }, "eDP-1"),
    { title: "Terminal" }, "active window belongs to focused monitor");
equal(context.activeWindowFor({ focused_monitor: "eDP-1", active_window: { title: "Terminal" } }, "DP-1"),
    null, "active window is hidden on other monitors");
equal(context.windowIconName({ initial_class: "ghostty", class_name: "fallback" }), "ghostty",
    "initial window class drives icon lookup");
equal(context.playerIcon({ desktop_entry: "spotify" }), "", "Spotify icon");
equal(context.playbackIcon({ playback_status: "paused" }), "", "paused icon");
equal(context.mediaPositionPercent({
    length_us: 240000000, position_us: 60000000, playback_status: "playing",
    position_observed_at_unix_ms: 1000, playback_rate: 1
}, 61000), 50, "media progress advances from observed position");
equal(context.mediaPositionPercent({
    length_us: 100, position_us: 90, playback_status: "playing",
    position_observed_at_unix_ms: 0, playback_rate: 2
}, 1000), 100, "media progress is bounded");
equal(context.audioIcon({ available: true, muted: false, volume_percent: 80 }), "", "high-volume icon");
equal(context.outputOsd({ available: true, muted: false, volume_percent: 80, sink_description: "Speakers" }), {
    kind: "audio", icon: "", label: "Speakers", valueLabel: "80%", percent: 80, progressVisible: true
}, "output OSD presentation");
equal(context.inputOsd({ input_muted: true, source_description: "Microphone" }), {
    kind: "input", icon: "󰍭", label: "Microphone", valueLabel: "Muted", percent: 0, progressVisible: false
}, "microphone OSD presentation");
equal(context.brightnessOsd({ percent: 65 }), {
    kind: "brightness", icon: "󰃠", label: "Brightness", valueLabel: "65%", percent: 65, progressVisible: true
}, "brightness OSD presentation");
equal(context.batteryIcon({ charging: true, plugged: true, percentage: 60 }), "󰂄", "charging icon");
equal(context.duration(7500), "2h 5m", "battery duration");
equal(context.networkKind({ active: true, access_point: { ssid: "Test" } }), "wifi", "Wi-Fi status");
equal(context.networkKind({ active: true, device_iface: "enp1s0" }), "ethernet", "Ethernet status");
equal(context.networkKind({ active: false }), "disconnected", "disconnected status");
equal(context.utcOffset(-18000), "-0500", "negative UTC offset");
equal(context.utcOffset(19800), "+0530", "fractional UTC offset");
const modules = context.statusModules({
    network: { active: false }, updates: { available: true, ready: true },
    bluetooth: { powered: true, allDevices: [] },
    audio: { available: true, muted: false, volume_percent: 50 },
    brightness: { available: true, percent: 70 },
    battery: { available: true, percentage: 80 },
    powerProfile: { available: true, profile: "balanced", driver: "test" },
    notifications: { count: 2, dnd: false },
    timezone: { available: true, city: "Taipei", abbreviation: "CST", utc_offset_seconds: 28800 }
}, new Date(0));
equal(modules.length, 10, "status module count");
equal(modules[0].primary, "wifi", "network action routing");
equal(modules[1].visible, true, "ready update visibility");
equal(modules[4].wheelDown, "brightness-down", "brightness wheel routing");
equal(modules[9].interactive, false, "clock is presentation-only");
equal(context.layoutDensity(1920), 0, "wide layout density");
equal(context.layoutDensity(1366), 1, "compact layout density");
equal(context.layoutDensity(900), 2, "narrow layout density");
equal(context.layoutDensity(600), 3, "ultra-narrow layout density");
equal(context.visibleStatusModules(modules, 0).length, 10, "wide layout modules");
equal(context.visibleStatusModules(modules, 1).map(module => module.id),
    ["network", "updates", "bluetooth", "audio", "brightness", "battery", "power", "notifications", "clock"],
    "compact layout modules");
equal(context.visibleStatusModules(modules, 2).map(module => module.id),
    ["network", "updates", "audio", "battery", "notifications", "clock"],
    "narrow layout modules");
equal(context.visibleStatusModules(modules, 3).map(module => module.id),
    ["network", "updates", "battery", "clock"], "ultra-narrow layout modules");
equal(context.moduleText(modules[5], 1), "󰂂", "compact battery text");
equal(context.moduleText(modules[9], 1), "HH:mm", "compact clock text");

console.log("bar presentation: workspace, responsive layout, and status formatting passed");
