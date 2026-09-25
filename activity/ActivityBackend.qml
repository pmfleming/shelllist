import QtQuick
import Shelllist.Io as Io
import "ActivityApi.js" as ActivityApi

Io.DaemonBackend {
    required property var controller
    daemonName: "bar-daemon"
    expectedProtocol: ActivityApi.protocol
    expectedVersion: ActivityApi.version
    streams: [ActivityApi.streams.activity, ActivityApi.streams.timezone]
    active: controller.uiActive

    function snapshot(): bool {
        return call("activity-snapshot", ActivityApi.methods.snapshot, {});
    }
    function queryRange(fromDate: date, toDate: date): bool {
        return callSequenced("activity-range", ActivityApi.methods.queryRange, {
            from_unix_ms: fromDate.getTime(),
            to_unix_ms: toDate.getTime()
        });
    }
    function refresh(): bool {
        return callSequenced("activity-refresh", ActivityApi.methods.refresh, {});
    }
    function createTodo(title: string, dueDate: string): bool {
        return callSequenced("todo-create", ActivityApi.methods.todoCreate, {
            title: title,
            due_unix_ms: null,
            due_date: dueDate.length > 0 ? dueDate : null,
            priority: 0
        });
    }
    function completeTodo(todoId: string, completed: bool): bool {
        return callSequenced("todo-complete", ActivityApi.methods.todoComplete, {
            id: todoId,
            completed: completed
        });
    }
    function deleteTodo(todoId: string): bool {
        return callSequenced("todo-delete", ActivityApi.methods.todoDelete, {
            id: todoId
        });
    }
    readonly property list<string> rangeChangingRequests: ["activity-refresh", "todo-create", "todo-complete", "todo-delete"]

    function finish(id: string, envelope: var, transportError: string): void {
        const kind = requestKind(id);
        const error = responseError(envelope, transportError, "Activity operation failed");
        if (error.length > 0) {
            controller.lastError = error;
            if (kind === "activity-range")
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
        if (rangeChangingRequests.includes(kind))
            controller.scheduleRangeQuery();
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventGapDetected: snapshot()
    onEventReceived: function (event) {
        controller.handleEvent(event);
    }
    onSendFailed: function (id, message) {
        controller.lastError = message;
    }
    onTransportFailed: function (message) {
        controller.lastError = message;
    }
    onTransportReady: snapshot()
}
