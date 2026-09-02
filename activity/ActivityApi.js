.pragma library
.import "../Bar/BarProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;

var methods = {
    snapshot: Protocol.methods["bar.snapshot"],
    queryRange: Protocol.methods["activity.queryRange"],
    refresh: Protocol.methods["activity.refresh"],
    todoCreate: Protocol.methods["todos.create"],
    todoComplete: Protocol.methods["todos.complete"],
    todoDelete: Protocol.methods["todos.delete"],
    notificationsToggleDnd: Protocol.methods["notifications.toggleDnd"],
    notificationsSetDnd: Protocol.methods["notifications.setDnd"],
    notificationsList: Protocol.methods["notifications.list"],
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
    notificationActive: Protocol.streams["notifications.active.changed"]
};

var subscribedStreams = [streams.activity, streams.notifications, streams.notificationActive];
