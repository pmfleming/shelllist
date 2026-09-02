import QtQuick
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "ActivityApi.js" as ActivityApi
import "ActivityFlow.js" as Flow

Ui.ChooserController {
    id: controller

    property var activity: ({ available: false, syncing: false, event_count: 0,
        incomplete_todo_count: 0, next_event: null, sources: [], world_clocks: [],
        weather_locations: [],
        weather: { available: false, id: "", location: "Local",
            error: "Weather is not configured" } })
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
    property string detailSection: "schedule"
    property string notificationFilter: "All"
    property string weatherLocationId: ""
    property string screenshotStatus: ""
    readonly property bool screenshotInFlight: screenshotCapture.inFlight

    detailsOpen: false
    closedWidthFraction: 0.285
    openWidthFraction: 0.66
    minimumClosedWindowWidth: 460
    maximumClosedWindowWidth: 760
    minimumOpenWindowWidth: 1040
    maximumOpenWindowWidth: 1840
    surfaceHeightRatio: 1
    surfaceTopInset: 51
    surfaceBottomInset: 0
    surfaceAlignment: "right"
    navigationPrimaryEnabled: false
    readonly property ActivityBackend backend: activityBackend
    readonly property string selectedDateKey: dateKey(selectedDate)
    readonly property var selectedEvents: events.filter(function (event) {
        return eventOverlapsDate(event, selectedDate);
    })
    readonly property var selectedTodos: todos.filter(function (todo) {
        return Flow.todoVisible(todo, selectedDateKey, dateKey(new Date()));
    })
    readonly property var activeNotificationGroups: Ui.NotificationPresentation.groupRecords(
        activeNotifications().slice().reverse())
    readonly property var notificationGroups: Ui.NotificationPresentation.groupRecords(
        notificationHistory)
    readonly property var filteredNotificationGroups: notificationGroups.filter(function (group) {
        return notificationGroupMatches(group, notificationFilter);
    })
    readonly property var weatherLocations: {
        const locations = activity.weather_locations || [];
        return locations.length > 0 ? locations
            : activity.weather ? [activity.weather] : [];
    }
    readonly property var selectedWeather: {
        const requested = weatherLocations.find(function (weather) {
            return weather.id === weatherLocationId;
        });
        return requested || weatherLocations.find(function (weather) { return weather.home; })
            || weatherLocations[0] || ({ available: false, location: "Local" });
    }

    signal focusTodoInputRequested

    function dateKey(value: date): string { return Flow.dateKey(value); }
    function startOfDay(value: date): date { return Flow.startOfDay(value); }
    function eventOverlapsDate(event: var, value: date): bool {
        return Flow.eventOverlapsDate(event, value);
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

    function applyDomainEvent(kind: string, data: var): void {
        if (kind === "activity") {
            activity = data;
            scheduleRangeQuery();
        } else if (kind === "notifications") {
            notifications = data;
            scheduleNotificationHistory();
        } else if (kind === "notificationActive") {
            notificationActive = data;
        }
    }
    function handleEvent(event: var): void {
        const kind = Flow.eventKind(event, ActivityApi.streams);
        if (kind === "lagged")
            backend.snapshot();
        else if (kind)
            applyDomainEvent(kind, event.data || ({}));
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

    function notificationGroupMatches(group: var, filter: string): bool {
        if (filter === "All")
            return true;
        if (filter === "Active")
            return group.records.some(function (record) {
                return isNotificationActive((record.notification || ({})).id);
            });
        const identity = String(group.appName || "").toLowerCase();
        if (filter === "Calendar")
            return identity.indexOf("calendar") >= 0;
        if (filter === "Messages")
            return ["message", "signal", "slack", "discord", "whatsapp", "telegram"]
                .some(function (name) { return identity.indexOf(name) >= 0; });
        return filter === "System"
            && !notificationGroupMatches(group, "Calendar")
            && !notificationGroupMatches(group, "Messages");
    }

    function activeNotifications(): var {
        return notificationActive && Array.isArray(notificationActive.notifications)
            ? notificationActive.notifications : [];
    }
    function isNotificationActive(notificationId: int): bool {
        return activeNotifications().some(function (notification) {
            return notification.id === notificationId;
        });
    }
    function isNotificationGroupActive(groupKey: string): bool {
        return activeNotifications().some(function (notification) {
            return Ui.NotificationPresentation.groupKey(notification) === groupKey;
        });
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
    function selectWeatherLocation(locationId: string): void {
        if (weatherLocations.some(function (weather) { return weather.id === locationId; }))
            weatherLocationId = locationId;
    }
    function cycleWeatherLocation(delta: int): void {
        if (weatherLocations.length < 2)
            return;
        const selectedId = selectedWeather.id;
        const current = weatherLocations.findIndex(function (weather) {
            return weather.id === selectedId;
        });
        const next = (Math.max(0, current) + delta + weatherLocations.length)
            % weatherLocations.length;
        weatherLocationId = weatherLocations[next].id;
    }

    function openSection(section: string): void {
        if (["weather", "schedule", "notifications"].indexOf(section) < 0)
            return;
        detailSection = section;
        detailsOpen = true;
    }
    function closeSection(): void { detailsOpen = false; }
    function captureScreenshot(x: real, y: real, width: real, height: real): bool {
        return screenshotCapture.captureRegion(x, y, width, height);
    }
    function refresh(): void { backend.refresh(); }
    function toggleDnd(): void { backend.toggleDnd(); }
    function setDndForMinutes(minutes: int): bool {
        return minutes > 0
            ? backend.setDnd(true, Date.now() + minutes * 60 * 1000)
            : backend.setDnd(false, null);
    }
    function dismissNotification(notificationId: int): bool {
        return backend.dismissNotification(notificationId);
    }
    function clearNotifications(): bool { return backend.clearNotifications(); }
    function clearNotificationGroup(groupKey: string): bool {
        return backend.clearNotificationGroup(groupKey);
    }
    function snoozeNotification(notificationId: int, minutes: int): bool {
        return backend.snoozeNotification(notificationId, Date.now() + minutes * 60 * 1000);
    }
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

    function deactivateUi() {
        deactivateUiState();
        closeSection();
        screenshotStatus = "";
    }

    onFocusSearchRequested: if (detailsOpen && detailSection === "schedule")
        focusTodoInputRequested()

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

    Io.ClipboardScreenshotCapture {
        id: screenshotCapture
        active: controller.uiActive
        startMessage: "Capturing Activity panel…"
        onStatusChanged: function (message) {
            controller.screenshotStatus = message;
            if (!inFlight)
                screenshotStatusTimer.restart();
        }
    }

    Timer {
        id: screenshotStatusTimer
        interval: 2500
        repeat: false
        onTriggered: controller.screenshotStatus = ""
    }
}
