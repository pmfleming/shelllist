import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import "ActivityApi.js" as ActivityApi

Io.DaemonBackend {
    required property var controller
    daemonName: "bar-daemon"
    expectedProtocol: ActivityApi.protocol
    expectedVersion: ActivityApi.version
    streams: ActivityApi.subscribedStreams
    // The resident BarBackend already owns these streams for the panel. Keep
    // this domain-specific command session only while Activity is visible.
    active: controller.uiActive
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

    function setDnd(enabled: bool, untilUnixMs: var): bool {
        return call(nextId("notifications-dnd"), ActivityApi.methods.notificationsSetDnd, {
            enabled: enabled,
            until_unix_ms: untilUnixMs
        });
    }

    function loadNotificationHistory(beforeHistoryId: var): bool {
        const prefix = beforeHistoryId === null || beforeHistoryId === undefined
            ? "notifications-history-reset" : "notifications-history-more";
        return call(nextId(prefix), ActivityApi.methods.notificationsList, {
            before_history_id: beforeHistoryId,
            limit: 50
        });
    }

    function dismissNotification(notificationId: int): bool {
        return call(nextId("notification-dismiss"),
            ActivityApi.methods.notificationsDismiss, { id: notificationId });
    }

    function clearNotifications(): bool {
        return call(nextId("notifications-clear"), ActivityApi.methods.notificationsClear, {});
    }

    function clearNotificationGroup(groupKey: string): bool {
        return call(nextId("notifications-clear-group"),
            ActivityApi.methods.notificationsClearGroup, { group_key: groupKey });
    }

    function snoozeNotification(notificationId: int, untilUnixMs: double): bool {
        return call(nextId("notification-snooze"), ActivityApi.methods.notificationsSnooze, {
            id: notificationId,
            until_unix_ms: untilUnixMs
        });
    }

    function invokeNotificationAction(notificationId: int, actionKey: string): bool {
        return call(nextId("notification-action"),
            ActivityApi.methods.notificationsInvokeAction, {
                id: notificationId,
                action_key: actionKey,
                activation_token: null
            });
    }

    function replyNotification(notificationId: int, text: string): bool {
        return call(nextId("notification-reply"), ActivityApi.methods.notificationsReply, {
            id: notificationId,
            text: text
        });
    }

    function finish(id: string, envelope: var, transportError: string): void {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            ActivityApi.protocol, ActivityApi.version, daemonName, "Activity operation failed");
        if (error.length > 0) {
            controller.lastError = error;
            if (id.startsWith("activity-range"))
                controller.rangeLoading = false;
            if (id.startsWith("notifications-history"))
                controller.notificationHistoryLoading = false;
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
        if (data.notification_history)
            controller.applyNotificationHistory(data.notification_history,
                id.startsWith("notifications-history-more"));
        if (id.startsWith("todo-") || id.startsWith("activity-refresh"))
            controller.scheduleRangeQuery();
        if (id.startsWith("notification-") || id.startsWith("notifications-clear")
                || id.startsWith("notifications-dnd"))
            controller.scheduleNotificationHistory();
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventReceived: function (event) { controller.handleEvent(event); }
    onSendFailed: function (id, message) { controller.lastError = message; }
    onTransportFailed: function (message) { controller.lastError = message; }
    onTransportReady: snapshot()
}
