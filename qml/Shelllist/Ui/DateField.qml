pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import QtQuick.Layouts

// One ordinary text-field transaction. Calendar clicks change its local buffer;
// Enter/Tab save, Escape/blur discard. The popup never takes native editor focus.
TextField {
    id: field
    readonly property var hostWindow: Window.window
    property bool calendarEnabled: true
    readonly property bool calendarVisible: calendar.visible
    property date candidate: new Date()
    property date displayedMonth: new Date()
    placeholder: "YYYY-MM-DD"
    trailingActionIcon: calendarEnabled ? "calendar_month" : ""
    trailingActionToolTip: qsTr("Choose date")
    trailingActionEnabled: enabled && !readOnly
    trailingAction.accessKey: "O"
    onTrailingActionRequested: {
        if (calendar.visible) { calendar.close(); return; }
        focusInput(false);
        const parsed = Date.fromLocaleString(Qt.locale("C"), text, "yyyy-MM-dd");
        candidate = isNaN(parsed.getTime()) ? new Date() : parsed;
        displayedMonth = candidate;
        calendar.open();
    }
    onInputActiveFocusChanged: if (!inputActiveFocus) calendar.close()
    onVisibleChanged: if (!visible) calendar.close()
    onEnabledChanged: if (!enabled) calendar.close()
    onReadOnlyChanged: if (readOnly) calendar.close()
    onKeyShortcutOverride: function(event) {
        if (calendar.visible && event.modifiers === Qt.NoModifier && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) event.accepted = true;
    }
    onKeyPressed: function(event) {
        if (!calendar.visible || event.modifiers !== Qt.NoModifier) return;
        let days = 0;
        if (event.key === Qt.Key_Left) days = -1;
        else if (event.key === Qt.Key_Right) days = 1;
        else if (event.key === Qt.Key_Up) days = -7;
        else if (event.key === Qt.Key_Down) days = 7;
        else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
            moveMonth(event.key === Qt.Key_PageUp ? -1 : 1);
            event.accepted = true;
            return;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            choose(candidate);
            editSession.handleKey(event);
            return;
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab) {
            calendar.close();
            editSession.handleKey(event);
            return;
        } else return;
        candidate = new Date(candidate.getFullYear(), candidate.getMonth(), candidate.getDate() + days, 12);
        displayedMonth = candidate;
        event.accepted = true;
    }
    function moveMonth(delta: int): void {
        displayedMonth = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth() + delta, 1, 12);
        candidate = displayedMonth;
    }
    function choose(date: date): void {
        text = Qt.formatDate(date, "yyyy-MM-dd");
        if (!editSession.active) edited(text);
        calendar.close();
    }
    Controls.Popup {
        id: calendar
        objectName: "dateCalendar"
        focus: false
        closePolicy: Controls.Popup.CloseOnPressOutside
        margins: Theme.spacingSm
        padding: Theme.spacingSm
        // Shared calendar owner: seven readable day targets, independent of the
        // narrow text column. Popup margins constrain this to the window.
        width: 7 * Theme.formActionSize + 2 * padding
        height: contentItem.implicitHeight + 2 * padding
        readonly property real anchorY: visible && field.hostWindow ? field.mapToItem(field.hostWindow.contentItem, 0, 0).y : 0
        y: anchorY + field.height + height + margins <= (field.hostWindow?.height || 0) ? field.height : -height
        background: Rectangle { color: Theme.surfaceRaised; radius: Theme.cardRadius; border.color: Theme.border; border.width: 1 }
        contentItem: ColumnLayout {
            spacing: Theme.spacingXs
            RowLayout {
                Layout.fillWidth: true
                FlatIconButton {
                    objectName: "datePreviousMonth"
                    icon: "chevron_left"
                    accessibleName: qsTr("Previous month")
                    pointerFocusTarget: field.trailingAction.pointerFocusTarget
                    onClicked: field.moveMonth(-1)
                }
                ThemeText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(field.displayedMonth, "MMMM yyyy")
                }
                FlatIconButton {
                    objectName: "dateNextMonth"
                    icon: "chevron_right"
                    accessibleName: qsTr("Next month")
                    pointerFocusTarget: field.trailingAction.pointerFocusTarget
                    onClicked: field.moveMonth(1)
                }
            }
            Controls.DayOfWeekRow {
                Layout.fillWidth: true
                locale: Qt.locale()
                delegate: ThemeText {
                    required property var model
                    text: model.shortName
                    color: Theme.mutedText
                    font.pixelSize: Theme.metadataSize
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            Controls.MonthGrid {
                id: days
                Layout.fillWidth: true
                Layout.preferredHeight: 6 * Theme.formActionSize
                month: field.displayedMonth.getMonth()
                year: field.displayedMonth.getFullYear()
                locale: Qt.locale()
                delegate: Rectangle {
                    id: day
                    required property var model
                    readonly property bool selected: Qt.formatDate(model.date, "yyyy-MM-dd") === Qt.formatDate(field.candidate, "yyyy-MM-dd")
                    objectName: "dateChoice:" + Qt.formatDate(model.date, "yyyy-MM-dd")
                    implicitWidth: Theme.formActionSize
                    implicitHeight: Theme.formActionSize
                    radius: Theme.spacingSm
                    color: selected ? Theme.selected : "transparent"
                    border.width: model.today ? 1 : 0
                    border.color: Theme.accent
                    Accessible.role: Accessible.Button
                    Accessible.name: Qt.formatDate(model.date, "dddd, d MMMM yyyy")
                    Accessible.selected: selected
                    Accessible.onPressAction: field.choose(model.date)
                    ThemeText {
                        anchors.centerIn: parent
                        text: day.model.day
                        color: day.selected ? Theme.selectedText : day.model.month === days.month ? Theme.text : Theme.mutedText
                    }
                    MouseArea { anchors.fill: parent; onClicked: field.choose(day.model.date) }
                }
            }
        }
    }
}
