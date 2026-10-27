import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserController {
    id: root
    readonly property AgendaController agendaController: agenda
    property string selectedDate: ""
    property string focusedDate: Qt.formatDate(new Date(), "yyyy-MM-dd")
    readonly property string today: markerReader.today
    property int windowStart: monthFor(today) - 4
    readonly property int monthCount: 9
    property real viewportOffset: 4 * monthHeight
    property real monthHeight: 336
    property bool returning: false
    property string focusRegion: "calendar"
    property bool initialized: false
    readonly property AgendaCalendarMarkers markerWindow: markerReader
    readonly property var markers: markerReader.days
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
    AgendaCalendarMarkers {
        id: markerReader
        active: root.uiActive
        fromDate: root.range().from_date
        toDate: root.range().to_date
    }
    function monthFor(key: string): int {
        return Number(key.slice(0, 4)) * 12 + Number(key.slice(5, 7)) - 1;
    }
    function monthKey(month: int): string {
        return Math.floor(month / 12).toString().padStart(4, "0") + "-" + (month % 12 + 1).toString().padStart(2, "0") + "-01";
    }
    function range(): var {
        const last = new Date(monthKey(windowStart + monthCount) + "T12:00:00Z");
        last.setUTCDate(0);
        return {from_date: monthKey(windowStart), to_date: last.toISOString().slice(0, 10)};
    }
    function chooseDay(key: string): void {
        if (navigationBlocked || !markerReader.validDate(key)) return;
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
    }
    function deactivateUi(): void {
        agenda.deactivateUi();
        deactivateUiState();
    }
    function restoreUiFocus(): void {
        if (!uiActive || uiSuspending) return;
        if (dayVisible && (focusRegion !== "calendar" || !composition.calendarVisible)) agenda.restoreUiFocus();
        else calendarFocusRequested();
    }
    function refresh(): void { markerReader.refresh(); if (agenda.uiActive) agenda.refresh(); }
    onUiSuspensionRequested: agenda.prepareUiDeactivation()
}
