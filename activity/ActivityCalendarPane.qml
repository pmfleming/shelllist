pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: pane

    required property ActivityController controller
    required property real uiScale
    required property date now

    function cellDate(index: int): date {
        const first = new Date(controller.viewDate.getFullYear(), controller.viewDate.getMonth(), 1);
        const mondayOffset = (first.getDay() + 6) % 7;
        return new Date(first.getFullYear(), first.getMonth(), index - mondayOffset + 1);
    }

    width: 360 * pane.uiScale
    height: parent.height
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border

    Column {
        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingMd
        spacing: Ui.Theme.spacingSm

        Row {
            width: parent.width
            height: 36
            ActivityHeaderButton { label: "‹"; onTriggered: pane.controller.shiftMonth(-1) }
            Text {
                width: parent.width - 2 * 38
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(pane.controller.viewDate, "MMMM yyyy")
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeHeading
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            ActivityHeaderButton { label: "›"; onTriggered: pane.controller.shiftMonth(1) }
        }

        Row {
            width: parent.width
            height: 22
            Repeater {
                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                Text {
                    required property string modelData
                    width: parent.width / 7
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }
        }

        Grid {
            width: parent.width
            height: width * 6 / 7
            columns: 7
            rows: 6
            Repeater {
                model: 42
                delegate: Rectangle {
                    id: dayCell
                    required property int index
                    readonly property date value: pane.cellDate(index)
                    readonly property bool selected: pane.controller.dateKey(value)
                        === pane.controller.selectedDateKey
                    readonly property bool today: pane.controller.dateKey(value)
                        === pane.controller.dateKey(pane.now)
                    readonly property bool inMonth: value.getMonth()
                        === pane.controller.viewDate.getMonth()
                    width: parent.width / 7
                    height: parent.height / 6
                    radius: Ui.Theme.controlRadius
                    color: selected ? Ui.Theme.selected
                        : dayPointer.containsMouse ? Ui.Theme.hover : "transparent"
                    border.color: today ? Ui.Theme.accent : "transparent"
                    border.width: today ? 1 : 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 7
                        text: dayCell.value.getDate()
                        color: dayCell.inMonth ? Ui.Theme.text : Ui.Theme.subtleText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeBody
                        font.weight: dayCell.selected || dayCell.today
                            ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
                    }
                    Rectangle {
                        visible: pane.controller.hasActivity(dayCell.value)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        width: 5
                        height: 5
                        radius: 3
                        color: Ui.Theme.accent
                    }
                    MouseArea {
                        id: dayPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.controller.selectDate(dayCell.value)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: Math.max(120, parent.height - y)
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.surfaceRaised
            border.color: Ui.Theme.border

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: Ui.Theme.spacingSm

                Row {
                    width: parent.width
                    height: 34
                    spacing: Ui.Theme.spacingSm
                    Text {
                        width: parent.width - dndButton.width - clearButton.width
                            - parent.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications  " + (pane.controller.notifications.count || 0)
                        color: Ui.Theme.text
                        elide: Text.ElideRight
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeLabel
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    ActivityHeaderButton {
                        id: dndButton
                        label: pane.controller.notifications.dnd ? "DND on" : "DND off"
                        onTriggered: pane.controller.toggleDnd()
                    }
                    ActivityHeaderButton {
                        id: clearButton
                        label: "Dismiss all"
                        enabled: pane.controller.notificationHistory.length > 0
                        onTriggered: pane.controller.clearNotifications()
                    }
                }

                Text {
                    visible: pane.controller.notificationHistory.length === 0
                    width: parent.width
                    text: pane.controller.notificationHistoryLoading
                        ? "Loading history…" : "No notification history"
                    color: Ui.Theme.mutedText
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeSmall
                }

                Ui.ScrollableListView {
                    width: parent.width
                    height: parent.height - y - historyFooter.height - parent.spacing
                    visible: pane.controller.notificationHistory.length > 0
                    clip: true
                    spacing: Ui.Theme.spacingSm
                    model: pane.controller.notificationHistory
                    delegate: NotificationHistoryRow {
                        required property var modelData
                        record: modelData
                        controller: pane.controller
                    }
                }

                Row {
                    id: historyFooter
                    width: parent.width
                    height: 32
                    spacing: Ui.Theme.spacingSm
                    ActivityHeaderButton {
                        label: "Refresh"
                        onTriggered: pane.controller.reloadNotificationHistory()
                    }
                    ActivityHeaderButton {
                        label: pane.controller.notificationHistoryLoading
                            ? "Loading…" : "Load more"
                        enabled: pane.controller.notificationHistoryHasMore
                            && !pane.controller.notificationHistoryLoading
                        onTriggered: pane.controller.loadMoreNotificationHistory()
                    }
                }
            }
        }
    }
}
