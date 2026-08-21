.pragma library

var protocol = "bar-api";
var version = 1;

var methods = {
    snapshot: "bar.snapshot",
    workspaceFocus: "workspace.focus",
    mediaOperation: "media.operation",
    audioAdjust: "audio.adjust",
    audioSetMuted: "audio.setMuted",
    audioSetInputMuted: "audio.setInputMuted",
    brightnessAdjust: "brightness.adjust",
    brightnessSet: "brightness.set",
    notificationsTogglePanel: "notifications.togglePanel",
    notificationsToggleDnd: "notifications.toggleDnd",
    notificationsDismiss: "notifications.dismiss",
    notificationsInvokeAction: "notifications.invokeAction",
    notificationsReply: "notifications.reply"
};

var streams = {
    activity: "activity.changed",
    workspaces: "workspaces.changed",
    media: "media.changed",
    audio: "audio.changed",
    brightness: "brightness.changed",
    battery: "battery.changed",
    powerProfile: "power-profile.changed",
    notifications: "notifications.changed",
    notificationActive: "notifications.active.changed",
    updates: "updates.changed",
    timezone: "timezone.changed"
};

var subscribedStreams = Object.keys(streams).map(function (name) { return streams[name]; });

var propertyByStream = {};
propertyByStream[streams.activity] = "activity";
propertyByStream[streams.workspaces] = "workspaces";
propertyByStream[streams.media] = "media";
propertyByStream[streams.audio] = "audio";
propertyByStream[streams.brightness] = "brightness";
propertyByStream[streams.battery] = "battery";
propertyByStream[streams.powerProfile] = "powerProfile";
propertyByStream[streams.notifications] = "notifications";
propertyByStream[streams.notificationActive] = "notificationActive";
propertyByStream[streams.updates] = "updates";
propertyByStream[streams.timezone] = "timezone";

var propertyByPayload = {
    activity: "activity",
    workspaces: "workspaces",
    media: "media",
    audio: "audio",
    brightness: "brightness",
    battery: "battery",
    power_profile: "powerProfile",
    notifications: "notifications",
    notification_active: "notificationActive",
    updates: "updates",
    timezone: "timezone"
};
