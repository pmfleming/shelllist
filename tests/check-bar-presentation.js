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
equal(context.playerIcon({ desktop_entry: "spotify" }), "", "Spotify icon");
equal(context.playbackIcon({ playback_status: "paused" }), "", "paused icon");
equal(context.audioIcon({ available: true, muted: false, volume_percent: 80 }), "", "high-volume icon");
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

console.log("bar presentation: workspace and status formatting passed");
