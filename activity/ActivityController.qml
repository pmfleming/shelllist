import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui
import "ActivityApi.js" as ActivityApi

Ui.ChooserController {
    id: controller

    property var activity: ({ available: false, syncing: false, event_count: 0,
        incomplete_todo_count: 0, next_event: null, sources: [], world_clocks: [] })
    property var notifications: ({ available: false, count: 0, dnd: false })
    property var notificationActive: ({ available: false, revision: 0, notifications: [] })
    property var notificationHistory: []
    property bool notificationHistoryLoading: false
    property bool notificationHistoryHasMore: false
    property var events: []
    property var todos: []
    property var busyDates: []
    property date selectedDate: startOfDay(new Date())
    property date viewDate: new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    property string lastError: ""
    property bool rangeLoading: false
    property date loadedFrom
    property date loadedTo

    detailsOpen: true
    navigationPrimaryEnabled: false
    readonly property ActivityBackend backend: activityBackend
    readonly property string selectedDateKey: dateKey(selectedDate)
    readonly property var selectedEvents: events.filter(function (event) {
        return eventOverlapsDate(event, selectedDate);
    })
    readonly property var selectedTodos: todos.filter(function (todo) {
        if (todo.due_date)
            return todo.due_date === selectedDateKey;
        if (todo.due_unix_ms !== null && todo.due_unix_ms !== undefined)
            return dateKey(new Date(todo.due_unix_ms)) === selectedDateKey;
        return selectedDateKey === dateKey(new Date()) && !todo.completed;
    })

    signal focusTodoInputRequested

    function dateKey(value: date): string {
        const year = value.getFullYear();
        const month = String(value.getMonth() + 1).padStart(2, "0");
        const day = String(value.getDate()).padStart(2, "0");
        return year + "-" + month + "-" + day;
    }

    function startOfDay(value: date): date {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate());
    }

    function eventOverlapsDate(event: var, value: date): bool {
        if (event.all_day && event.start_date) {
            const end = event.end_date || event.start_date;
            return event.start_date <= dateKey(value) && end > dateKey(value);
        }
        const start = startOfDay(value).getTime();
        const end = start + 24 * 60 * 60 * 1000;
        return Number(event.end_unix_ms) > start && Number(event.start_unix_ms) < end;
    }

    function monthRange(): var {
        const from = new Date(viewDate.getFullYear(), viewDate.getMonth(), -6);
        const to = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 8);
        return { from: from, to: to };
    }

    function applySnapshot(snapshot: var): void {
        if (snapshot.activity)
            activity = snapshot.activity;
        if (snapshot.notifications)
            notifications = snapshot.notifications;
        if (snapshot.notification_active)
            notificationActive = snapshot.notification_active;
        scheduleRangeQuery();
        scheduleNotificationHistory();
    }

    function applyNotificationHistory(records: var, append: bool): void {
        const values = Array.isArray(records) ? records : [];
        notificationHistory = append ? notificationHistory.concat(values) : values;
        notificationHistoryHasMore = values.length === 50;
        notificationHistoryLoading = false;
    }

    function applyRange(range: var): void {
        events = range.events || [];
        todos = range.todos || [];
        busyDates = range.busy_dates || [];
        loadedFrom = new Date(range.from_unix_ms);
        loadedTo = new Date(range.to_unix_ms);
        rangeLoading = false;
    }

    function handleEvent(event: var): void {
        const compatibility = Core.ApiEnvelope.compatibilityError(event,
            ActivityApi.protocol, ActivityApi.version, "bar-daemon");
        if (compatibility.length > 0) {
            lastError = compatibility;
            return;
        }
        if (event.event === "lagged") {
            backend.snapshot();
            return;
        }
        if (event.event !== "subscribed" && event.event !== "changed")
            return;
        if (event.stream === ActivityApi.streams.activity) {
            activity = event.data || ({});
            scheduleRangeQuery();
        } else if (event.stream === ActivityApi.streams.notifications) {
            notifications = event.data || ({});
            scheduleNotificationHistory();
        } else if (event.stream === ActivityApi.streams.notificationActive) {
            notificationActive = event.data || ({});
        }
    }

    function scheduleRangeQuery(): void { rangeQueryDebounce.restart(); }
    function scheduleNotificationHistory(): void { notificationHistoryDebounce.restart(); }

    function reloadNotificationHistory(): void {
        notificationHistoryLoading = backend.loadNotificationHistory(null);
    }

    function loadMoreNotificationHistory(): void {
        if (notificationHistoryLoading || !notificationHistoryHasMore
                || notificationHistory.length === 0)
            return;
        const cursor = notificationHistory[notificationHistory.length - 1].history_id;
        notificationHistoryLoading = backend.loadNotificationHistory(cursor);
    }

    function isNotificationActive(notificationId: int): bool {
        const values = notificationActive && Array.isArray(notificationActive.notifications)
            ? notificationActive.notifications : [];
        return values.some(function (notification) { return notification.id === notificationId; });
    }

    function queryVisibleRange(): void {
        const range = monthRange();
        rangeLoading = backend.queryRange(range.from, range.to);
    }

    function selectDate(value: date): void {
        selectedDate = startOfDay(value);
        if (selectedDate.getMonth() !== viewDate.getMonth()
                || selectedDate.getFullYear() !== viewDate.getFullYear()) {
            viewDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1);
            scheduleRangeQuery();
        }
    }

    function shiftMonth(delta: int): void {
        const target = new Date(viewDate.getFullYear(), viewDate.getMonth() + delta, 1);
        const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate();
        viewDate = target;
        selectedDate = new Date(target.getFullYear(), target.getMonth(),
            Math.min(selectedDate.getDate(), lastDay));
        scheduleRangeQuery();
    }

    function goToToday(): void {
        const today = startOfDay(new Date());
        selectedDate = today;
        viewDate = new Date(today.getFullYear(), today.getMonth(), 1);
        scheduleRangeQuery();
    }

    function hasActivity(dateValue: date): bool {
        return busyDates.indexOf(dateKey(dateValue)) >= 0;
    }

    function createTodo(title: string): bool {
        return backend.createTodo(title, selectedDateKey);
    }
    function toggleTodo(todo: var): bool { return backend.completeTodo(todo.id, !todo.completed); }
    function deleteTodo(todo: var): bool { return backend.deleteTodo(todo.id); }
    function refresh(): void { backend.refresh(); }
    function toggleDnd(): void { backend.toggleDnd(); }
    function dismissNotification(notificationId: int): bool {
        return backend.dismissNotification(notificationId);
    }
    function clearNotifications(): bool { return backend.clearNotifications(); }
    function invokeNotificationAction(notificationId: int, actionKey: string): bool {
        return backend.invokeNotificationAction(notificationId, actionKey);
    }
    function replyNotification(notificationId: int, text: string): bool {
        return backend.replyNotification(notificationId, text);
    }

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        scheduleRangeQuery();
        scheduleNotificationHistory();
    }

    onFocusSearchRequested: focusTodoInputRequested()

    Timer {
        id: notificationHistoryDebounce
        interval: 120
        repeat: false
        onTriggered: controller.reloadNotificationHistory()
    }

    Timer {
        id: rangeQueryDebounce
        interval: 120
        repeat: false
        onTriggered: controller.queryVisibleRange()
    }

    ActivityBackend { id: activityBackend; controller: controller }
}
