.pragma library

var protocol = "bar-api";
var version = 1;

var methods = {
    snapshot: "bar.snapshot",
    queryRange: "activity.queryRange",
    refresh: "activity.refresh",
    todoCreate: "todos.create",
    todoComplete: "todos.complete",
    todoDelete: "todos.delete",
    notificationsToggleDnd: "notifications.toggleDnd",
    notificationsSetDnd: "notifications.setDnd",
    notificationsList: "notifications.list",
    notificationsDismiss: "notifications.dismiss",
    notificationsClear: "notifications.clear",
    notificationsClearGroup: "notifications.clearGroup",
    notificationsSnooze: "notifications.snooze",
    notificationsInvokeAction: "notifications.invokeAction",
    notificationsReply: "notifications.reply"
};

var streams = {
    activity: "activity.changed",
    notifications: "notifications.changed",
    notificationActive: "notifications.active.changed"
};

var subscribedStreams = [streams.activity, streams.notifications, streams.notificationActive];
