.pragma library
.import "../Bar/BarProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;

var methods = {
    snapshot: Protocol.methods["bar.snapshot"],
    queryRange: Protocol.methods["activity.queryRange"],
    refresh: Protocol.methods["activity.refresh"],
    locationsSearch: Protocol.methods["locations.search"],
    locationsAdd: Protocol.methods["locations.add"],
    locationsRemove: Protocol.methods["locations.remove"],
    locationStatus: Protocol.methods["location.status"],
    locationSetManual: Protocol.methods["location.setManual"],
    locationAutomatic: Protocol.methods["location.returnToAutomatic"],
    todoCreate: Protocol.methods["todos.create"],
    todoComplete: Protocol.methods["todos.complete"],
    todoDelete: Protocol.methods["todos.delete"],
    notificationsSetDnd: Protocol.methods["notifications.setDnd"],
    notificationsSetReading: Protocol.methods["notifications.setReading"],
    notificationsSetSettings: Protocol.methods["notifications.setSettings"],
    notificationsContextAction: Protocol.methods["notifications.contextAction"],
    notificationsSnoozeSharing: Protocol.methods["notifications.snoozeSharing"],
    notificationsSetAppPolicy: Protocol.methods["notifications.setAppPolicy"],
    notificationsPrepareDelete: Protocol.methods["notifications.prepareDelete"],
    notificationsDelete: Protocol.methods["notifications.delete"],
    notificationsQueryCenter: Protocol.methods["notifications.queryCenter"],
    notificationsDismiss: Protocol.methods["notifications.dismiss"],
    notificationsClear: Protocol.methods["notifications.clear"],
    notificationsClearGroup: Protocol.methods["notifications.clearGroup"],
    notificationsSnooze: Protocol.methods["notifications.snooze"],
    notificationsInvokeAction: Protocol.methods["notifications.invokeAction"],
    notificationsReply: Protocol.methods["notifications.reply"]
};

var streams = {
    activity: Protocol.streams["activity.changed"],
    notifications: Protocol.streams["notifications.changed"],
    notificationActive: Protocol.streams["notifications.active.changed"],
    timezone: Protocol.streams["timezone.changed"]
};
