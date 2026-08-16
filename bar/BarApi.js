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
    notificationsTogglePanel: "notifications.togglePanel",
    notificationsToggleDnd: "notifications.toggleDnd"
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

var subscribedStreams = Object.keys(streams).map(function (name) { return streams[name]; });

var propertyByStream = {};
propertyByStream[streams.workspaces] = "workspaces";
propertyByStream[streams.media] = "media";
propertyByStream[streams.audio] = "audio";
propertyByStream[streams.brightness] = "brightness";
propertyByStream[streams.battery] = "battery";
propertyByStream[streams.powerProfile] = "powerProfile";
propertyByStream[streams.notifications] = "notifications";
propertyByStream[streams.updates] = "updates";
propertyByStream[streams.timezone] = "timezone";

var propertyByPayload = {
    workspaces: "workspaces",
    media: "media",
    audio: "audio",
    brightness: "brightness",
    battery: "battery",
    power_profile: "powerProfile",
    notifications: "notifications",
    updates: "updates",
    timezone: "timezone"
};
