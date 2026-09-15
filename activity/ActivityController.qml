import QtQuick
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "ActivityApi.js" as ActivityApi
import "ActivityFlow.js" as Flow

Ui.ChooserController {
    id: controller

    property var activity: ({
            available: false,
            syncing: false,
            event_count: 0,
            incomplete_todo_count: 0,
            next_event: null,
            sources: [],
            world_clocks: [],
            weather_locations: [],
            weather: {
                available: false,
                id: "",
                location: "Local",
                error: "Weather is not configured"
            }
        })
    property NotificationState notificationState: NotificationState {
        uiActive: controller.uiActive
    }
    readonly property var notifications: notificationState.notifications
    property bool preserveNavigationOnDeactivate: false
    property var timezone: ({
            available: false,
            timezone: "",
            city: "",
            abbreviation: "",
            utc_offset_seconds: 0
        })
    property bool rangeQueriesEnabled: true
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
    property string weatherLocationId: ""
    property string screenshotStatus: ""
    property string screenshotStartMessage: "Capturing Activity panel…"
    readonly property bool screenshotInFlight: screenshotCapture.inFlight

    detailsOpen: false
    closedWidthFraction: 0.285
    openWidthFraction: 0.66
    minimumClosedWindowWidth: 460
    maximumClosedWindowWidth: 760
    minimumOpenWindowWidth: 1040
    maximumOpenWindowWidth: 1840
    surfaceHeightRatio: 1
    surfaceFitsWorkspace: true
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
    readonly property var weatherLocations: {
        const locations = activity.weather_locations || [];
        return locations.length > 0 ? locations : activity.weather ? [activity.weather] : [];
    }
    readonly property var selectedWeather: {
        const requested = weatherLocations.find(function (weather) {
            return weather.id === weatherLocationId;
        });
        return requested || weatherLocations.find(function (weather) {
            return weather.home;
        }) || weatherLocations[0] || ({
                available: false,
                location: "Local"
            });
    }

    signal focusTodoInputRequested
    signal timeWeatherRequested(string tab)
    signal notificationsRequested(string groupKey, string tab)

    function requestNotifications(groupKey: string, tab: string): void {
        preserveNavigationOnDeactivate = true;
        notificationsRequested(groupKey, tab);
    }

    function dateKey(value: date): string {
        return Flow.dateKey(value);
    }
    function startOfDay(value: date): date {
        return Flow.startOfDay(value);
    }
    function eventOverlapsDate(event: var, value: date): bool {
        return Flow.eventOverlapsDate(event, value);
    }

    function monthRange(): var {
        const from = new Date(viewDate.getFullYear(), viewDate.getMonth(), -6);
        const to = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 8);
        return {
            from: from,
            to: to
        };
    }

    function applySnapshot(snapshot: var): void {
        if (snapshot.activity)
            activity = snapshot.activity;
        notificationState.applySnapshot(snapshot);
        if (snapshot.timezone)
            timezone = snapshot.timezone;
        scheduleRangeQuery();
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
            notificationState.notifications = data;
        } else if (kind === "notificationActive") {
            notificationState.notificationActive = data;
        } else if (kind === "timezone") {
            timezone = data;
        }
    }
    function handleEvent(event: var): void {
        const kind = Flow.eventKind(event, ActivityApi.streams);
        if (kind)
            applyDomainEvent(kind, event.data || ({}));
    }

    function scheduleRangeQuery(): void {
        if (rangeQueriesEnabled)
            rangeQueryDebounce.restart();
    }
    function queryVisibleRange(): void {
        const range = monthRange();
        rangeLoading = backend.queryRange(range.from, range.to);
    }

    function selectDate(value: date): void {
        selectedDate = startOfDay(value);
        if (selectedDate.getMonth() !== viewDate.getMonth() || selectedDate.getFullYear() !== viewDate.getFullYear()) {
            viewDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1);
            scheduleRangeQuery();
        }
    }

    function shiftMonth(delta: int): void {
        const target = new Date(viewDate.getFullYear(), viewDate.getMonth() + delta, 1);
        const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate();
        viewDate = target;
        selectedDate = new Date(target.getFullYear(), target.getMonth(), Math.min(selectedDate.getDate(), lastDay));
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
    function toggleTodo(todo: var): bool {
        return backend.completeTodo(todo.id, !todo.completed);
    }
    function deleteTodo(todo: var): bool {
        return backend.deleteTodo(todo.id);
    }
    function selectWeatherLocation(locationId: string): void {
        if (weatherLocations.some(function (weather) {
            return weather.id === locationId;
        }))
            weatherLocationId = locationId;
    }
    function cycleWeatherLocation(delta: int): void {
        if (weatherLocations.length < 2)
            return;
        const selectedId = selectedWeather.id;
        const current = weatherLocations.findIndex(function (weather) {
            return weather.id === selectedId;
        });
        const next = (Math.max(0, current) + delta + weatherLocations.length) % weatherLocations.length;
        weatherLocationId = weatherLocations[next].id;
    }

    function requestTimeWeather(tab: string): void {
        timeWeatherRequested(tab === "time" ? "time" : "weather");
    }

    function openSection(section: string): void {
        if (section === "notifications") {
            requestNotifications("", "active");
            return;
        }
        if (section !== "schedule")
            return;
        detailSection = section;
        detailsOpen = true;
    }
    function closeSection(): void {
        detailsOpen = false;
    }
    function captureScreenshot(x: real, y: real, width: real, height: real): bool {
        return screenshotCapture.captureRegion(x, y, width, height);
    }
    function refresh(): void {
        backend.refresh();
    }
    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        scheduleRangeQuery();
    }

    function deactivateUi() {
        deactivateUiState();
        if (!preserveNavigationOnDeactivate)
            closeSection();
        preserveNavigationOnDeactivate = false;
        screenshotStatus = "";
    }

    onFocusSearchRequested: if (detailsOpen && detailSection === "schedule")
        focusTodoInputRequested()

    Timer {
        id: rangeQueryDebounce
        interval: 120
        repeat: false
        onTriggered: controller.queryVisibleRange()
    }

    ActivityBackend {
        id: activityBackend
        controller: controller
    }

    Io.ClipboardScreenshotCapture {
        id: screenshotCapture
        active: controller.uiActive
        startMessage: controller.screenshotStartMessage
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
