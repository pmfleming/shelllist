import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Io as Io
import "ActivityApi.js" as ActivityApi

Ui.ChooserController {
    id: root
    readonly property AgendaController agendaController: agenda
    property string selectedDate: ""
    property string focusedDate: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property string today: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property int windowStart: monthFor(today) - 4
    readonly property int monthCount: 9
    property real viewportOffset: 4 * monthHeight
    property real monthHeight: 336
    property bool returning: false
    property string focusRegion: "calendar"
    property bool initialized: false
    property var markers: ({})
    property real catalogRevision: -1
    property string timezone: ""
    property string error: ""
    property string latestRead: ""
    property string latestRange: ""
    readonly property bool dayVisible: selectedDate.length > 0 && !returning
    readonly property Ui.CalendarComposition composition: Ui.CalendarComposition {
        availableWidth: root.geometry.availableWidth
        edgeMargin: root.geometry.edgeMargin
        baseWidth: agenda.closedWindowWidth
        adjacentWidth: agenda.currentWindowWidth
        gap: agenda.detailsGapWidth
        daySelected: root.selectedDate.length > 0
        returning: root.returning
    }
    compositionWidth: composition.width
    geometry.horizontalOverflowAllowed: false
    navigationBlocked: agenda.navigationBlocked

    signal revealDateRequested(string dateKey)
    signal calendarFocusRequested

    AgendaController {
        id: agenda
        dayScope: root.selectedDate
        availableScreenWidth: root.availableScreenWidth
        availableScreenHeight: root.availableScreenHeight
        onCloseWindowRequested: root.returnToCalendar()
    }
    function monthFor(key: string): int {
        return Number(key.slice(0, 4)) * 12 + Number(key.slice(5, 7)) - 1;
    }
    function monthKey(month: int): string {
        return Math.floor(month / 12).toString().padStart(4, "0") + "-" + (month % 12 + 1).toString().padStart(2, "0") + "-01";
    }
    function validDate(key: var): bool {
        if (typeof key !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(key)) return false;
        const value = new Date(key + "T12:00:00Z");
        return Number.isFinite(value.getTime()) && value.toISOString().slice(0, 10) === key;
    }
    function range(): var {
        const last = new Date(monthKey(windowStart + monthCount) + "T12:00:00Z");
        last.setUTCDate(0);
        return {from_date: monthKey(windowStart), to_date: last.toISOString().slice(0, 10)};
    }
    function chooseDay(key: string): void {
        if (navigationBlocked || !validDate(key)) return;
        navigationInteracted();
        selectedDate = key;
        focusedDate = key;
        focusRegion = "agenda";
        returning = false;
        if (uiActive && !agenda.uiActive) agenda.activateUi(currentWorkspaceId);
        Qt.callLater(agenda.restoreUiFocus);
    }
    function returnToCalendar(): void {
        if (navigationBlocked) return;
        navigationInteracted();
        returning = true;
        focusRegion = "calendar";
        calendarFocusRequested();
    }
    function moveMonth(delta: int): void {
        if (navigationBlocked) return;
        navigationInteracted();
        const top = windowStart + Math.floor(viewportOffset / monthHeight);
        revealDateRequested(monthKey(top + delta));
    }
    function goToday(): void {
        if (navigationBlocked) return;
        navigationInteracted();
        focusedDate = today;
        focusRegion = "calendar";
        revealDateRequested(today);
        calendarFocusRequested();
    }
    function activateUi(workspaceId): void {
        activateUiState(workspaceId);
        if (!initialized) {
            initialized = true;
            windowStart = monthFor(today) - 4;
            viewportOffset = 4 * monthHeight;
        }
        if (selectedDate.length > 0) agenda.activateUi(workspaceId);
        scheduleMarkers();
    }
    function deactivateUi(): void {
        latestRead = "";
        agenda.deactivateUi();
        deactivateUiState();
    }
    function restoreUiFocus(): void {
        if (!uiActive || uiSuspending) return;
        if (dayVisible && (focusRegion !== "calendar" || !composition.calendarVisible)) agenda.restoreUiFocus();
        else calendarFocusRequested();
    }
    function refresh(): void { scheduleMarkers(); if (agenda.uiActive) agenda.refresh(); }
    function scheduleMarkers(): void {
        if (!uiActive) return;
        latestRead = ""; // Invalidation fences in-flight reads before debounce.
        markerTimer.restart();
    }
    onWindowStartChanged: scheduleMarkers()
    onUiSuspensionRequested: agenda.prepareUiDeactivation()

    function readMarkers(): void {
        if (!uiActive || !backend.ready) return;
        const bounds = range();
        latestRead = backend.nextRequestId("agenda-markers");
        latestRange = JSON.stringify(bounds);
        backend.call(latestRead, "agenda.markers", bounds);
    }
    function acceptMarkers(id: string, data: var, failure: string): bool {
        if (id !== latestRead || !uiActive || latestRange !== JSON.stringify(range())) return false;
        latestRead = "";
        if (failure) { error = failure; return false; }
        if (data && Number.isSafeInteger(data.catalog_revision)
            && data.catalog_revision < Math.max(catalogRevision, AgendaRepository.catalogRevision)) {
            scheduleMarkers(); return false;
        }
        if (!data || !Array.isArray(data.days) || data.days.length > 370
            || !Number.isSafeInteger(data.catalog_revision) || data.catalog_revision < 0
            || !validDate(data.today) || typeof data.timezone !== "string" || !data.timezone.length) {
            error = qsTr("Invalid calendar marker window"); return false;
        }
        const bounds = range();
        const next = {};
        for (const day of data.days) {
            if (!day || !validDate(day.date) || day.date < bounds.from_date || day.date > bounds.to_date
                || typeof day.event !== "boolean" || typeof day.task !== "boolean" || next[day.date]) {
                error = qsTr("Invalid calendar marker window"); return false;
            }
            next[day.date] = {event: day.event, task: day.task};
        }
        markers = next;
        catalogRevision = data.catalog_revision;
        AgendaRepository.catalogRevision = Math.max(AgendaRepository.catalogRevision, catalogRevision);
        today = data.today;
        timezone = data.timezone;
        error = "";
        return true;
    }
    Connections {
        target: AgendaRepository
        function onInvalidated(): void { root.scheduleMarkers(); }
    }
    Timer { id: markerTimer; interval: 30; onTriggered: root.readMarkers() }
    // Native reads reproject local midnight/zone; this timer never infers membership.
    Timer { interval: 60000; repeat: true; running: root.uiActive; onTriggered: root.scheduleMarkers() }
    Io.DaemonBackend {
        id: backend
        daemonName: "bar-daemon"
        expectedProtocol: ActivityApi.protocol
        expectedVersion: ActivityApi.version
        streams: [ActivityApi.streams.activity, ActivityApi.streams.timezone]
        active: root.uiActive
        onTransportReady: root.scheduleMarkers()
        onEventReceived: root.scheduleMarkers()
        onResponseReceived: function(id, envelope, transportError) {
            root.acceptMarkers(id, envelope?.data, responseError(envelope, transportError, qsTr("Calendar read failed")));
        }
        onSendFailed: function(id, message) { root.acceptMarkers(id, null, message); }
        onTransportFailed: function(message) { root.latestRead = ""; root.error = message; }
    }
}
