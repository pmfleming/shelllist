.pragma library
.import "BarProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;

var methods = {
    snapshot: Protocol.methods["bar.snapshot"],
    workspaceFocus: Protocol.methods["workspace.focus"],
    mediaOperation: Protocol.methods["media.operation"],
    audioAdjust: Protocol.methods["audio.adjust"],
    audioSetMuted: Protocol.methods["audio.setMuted"],
    audioSetInputMuted: Protocol.methods["audio.setInputMuted"],
    brightnessAdjust: Protocol.methods["brightness.adjust"],
    brightnessSet: Protocol.methods["brightness.set"],
    powerProfileSet: Protocol.methods["powerProfile.set"],
    notificationsTogglePanel: Protocol.methods["notifications.togglePanel"],
    notificationsToggleDnd: Protocol.methods["notifications.toggleDnd"],
    notificationsDismiss: Protocol.methods["notifications.dismiss"],
    notificationsClearGroup: Protocol.methods["notifications.clearGroup"],
    notificationsSnooze: Protocol.methods["notifications.snooze"],
    notificationsInvokeAction: Protocol.methods["notifications.invokeAction"],
    notificationsReply: Protocol.methods["notifications.reply"]
};

var streams = {
    activity: Protocol.streams["activity.changed"],
    workspaces: Protocol.streams["workspaces.changed"],
    media: Protocol.streams["media.changed"],
    audio: Protocol.streams["audio.changed"],
    brightness: Protocol.streams["brightness.changed"],
    battery: Protocol.streams["battery.changed"],
    powerProfile: Protocol.streams["power-profile.changed"],
    powerSleep: Protocol.streams["power-sleep.changed"],
    osdHardware: Protocol.streams["osd-hardware.changed"],
    notifications: Protocol.streams["notifications.changed"],
    notificationActive: Protocol.streams["notifications.active.changed"],
    updates: Protocol.streams["updates.changed"],
    timezone: Protocol.streams["timezone.changed"]
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
propertyByStream[streams.powerSleep] = "powerSleep";
propertyByStream[streams.osdHardware] = "osdHardware";
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
    power_sleep: "powerSleep",
    osd_hardware: "osdHardware",
    notifications: "notifications",
    notification_active: "notificationActive",
    updates: "updates",
    timezone: "timezone"
};
