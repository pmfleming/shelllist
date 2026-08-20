import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import "ActivityApi.js" as ActivityApi

Io.DaemonBackend {
    id: backend

    required property var controller
    daemonName: "bar-daemon"
    streams: ActivityApi.subscribedStreams
    active: true
    property int sequence: 0

    function nextId(prefix: string): string {
        sequence += 1;
        return prefix + "-" + sequence;
    }

    function snapshot(): bool {
        return call("activity-snapshot", ActivityApi.methods.snapshot, {});
    }

    function queryRange(fromDate: date, toDate: date): bool {
        return call(nextId("activity-range"), ActivityApi.methods.queryRange, {
            from_unix_ms: fromDate.getTime(),
            to_unix_ms: toDate.getTime()
        });
    }

    function refresh(): bool {
        return call(nextId("activity-refresh"), ActivityApi.methods.refresh, {});
    }

    function createTodo(title: string, dueDate: string): bool {
        return call(nextId("todo-create"), ActivityApi.methods.todoCreate, {
            title: title,
            due_unix_ms: null,
            due_date: dueDate.length > 0 ? dueDate : null,
            priority: 0
        });
    }

    function completeTodo(todoId: string, completed: bool): bool {
        return call(nextId("todo-complete"), ActivityApi.methods.todoComplete, {
            id: todoId,
            completed: completed
        });
    }

    function deleteTodo(todoId: string): bool {
        return call(nextId("todo-delete"), ActivityApi.methods.todoDelete, { id: todoId });
    }

    function toggleDnd(): bool {
        return call(nextId("notifications-dnd"), ActivityApi.methods.notificationsToggleDnd, {});
    }

    function openNotificationHistory(): bool {
        return call(nextId("notifications-history"), ActivityApi.methods.notificationsTogglePanel, {});
    }

    function finish(id: string, envelope: var, transportError: string): void {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            ActivityApi.protocol, ActivityApi.version, daemonName, "Activity operation failed");
        if (error.length > 0) {
            controller.lastError = error;
            if (id.startsWith("activity-range"))
                controller.rangeLoading = false;
            return;
        }
        controller.lastError = "";
        const data = envelope.data || ({});
        if (data.snapshot)
            controller.applySnapshot(data.snapshot);
        if (data.activity)
            controller.activity = data.activity;
        if (data.activity_range)
            controller.applyRange(data.activity_range);
        if (id.startsWith("todo-") || id.startsWith("activity-refresh"))
            controller.scheduleRangeQuery();
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventReceived: function (event) { controller.handleEvent(event); }
    onSendFailed: function (id, message) { controller.lastError = message; }
    onTransportFailed: function (message) { controller.lastError = message; }
    onTransportReady: snapshot()
}
