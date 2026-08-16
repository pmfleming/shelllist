.pragma library

var protocol = "bar-api";
var version = 1;

var methods = {
    snapshot: "bar.snapshot",
    workspaceFocus: "workspace.focus",
    mediaOperation: "media.operation",
    audioAdjust: "audio.adjust",
    audioSetMuted: "audio.setMuted",
    brightnessAdjust: "brightness.adjust",
    brightnessSet: "brightness.set",
    powerProfileSet: "powerProfile.set",
    notificationsTogglePanel: "notifications.togglePanel",
    notificationsToggleDnd: "notifications.toggleDnd",
    updatesRefresh: "updates.refresh"
};

var streams = {
    workspaces: "workspaces.changed",
    media: "media.changed",
    audio: "audio.changed",
    brightness: "brightness.changed",
    battery: "battery.changed",
    powerProfile: "power-profile.changed",
    notifications: "notifications.changed",
    updates: "updates.changed",
    timezone: "timezone.changed"
};

var subscribedStreams = [
    streams.workspaces,
    streams.media,
    streams.audio,
    streams.brightness,
    streams.battery,
    streams.powerProfile,
    streams.notifications,
    streams.updates,
    streams.timezone
];
