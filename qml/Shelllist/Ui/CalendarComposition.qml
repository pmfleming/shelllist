import QtQuick

// Measured adjacent-pane fit. All input widths include their own surface insets.
// Calendar geometry owner: Agenda; no emergency horizontal panning policy.
QtObject {
    property real availableWidth: 1280
    property real edgeMargin: 16
    property real baseWidth: Theme.popupClosedWidth
    property real adjacentWidth: 0
    property real gap: Theme.detailsGapWidth
    property bool daySelected: false
    property bool returning: false
    readonly property real budget: Math.max(1, availableWidth - 2 * edgeMargin)
    readonly property real visibleAdjacentWidth: daySelected && !returning ? adjacentWidth : 0
    readonly property real paneGap: visibleAdjacentWidth > 0 ? gap : 0
    readonly property real calendarWidth: budget >= 1.5 * baseWidth + paneGap + visibleAdjacentWidth
        ? 1.5 * baseWidth : budget >= baseWidth + paneGap + visibleAdjacentWidth
        ? baseWidth : visibleAdjacentWidth > 0 ? 0 : baseWidth
    readonly property bool calendarVisible: calendarWidth > 0
    readonly property real width: calendarWidth + (calendarVisible ? paneGap : 0) + visibleAdjacentWidth
    readonly property bool supported: width <= budget
}
