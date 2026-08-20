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
    notificationsTogglePanel: "notifications.togglePanel",
    notificationsToggleDnd: "notifications.toggleDnd"
};

var streams = {
    activity: "activity.changed",
    notifications: "notifications.changed"
};

var subscribedStreams = [streams.activity, streams.notifications];
