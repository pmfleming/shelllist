pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: card
    required property ActivityController controller
    required property date now
    readonly property date firstDay: new Date(controller.viewDate.getFullYear(), controller.viewDate.getMonth(), 1)
    readonly property int firstDayOffset: (firstDay.getDay() + 6) % 7
    readonly property string todayKey: controller.dateKey(now)

    function eventTime(event: var): string {
        if (!event)
            return qsTr("No upcoming events");
        return event.all_day ? qsTr("All day") : Qt.formatTime(new Date(event.start_unix_ms), "HH:mm");
    }
    width: parent.width
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border

    Column {
        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingMd
        spacing: Ui.Theme.spacingSm

        Row {
            width: parent.width
            height: 24
            Ui.ThemeText {
                width: parent.width - scheduleExpand.width
                text: "Calendar · Agenda · Todo    " + String(card.controller.activity.incomplete_todo_count || 0)
                font.pixelSize: Ui.Theme.fontSizeLabel
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Ui.ThemeText {
                id: scheduleExpand
                text: "↗"
                color: Ui.Theme.accent
                font.pixelSize: Ui.Theme.fontSizeHeading
            }
        }
        Ui.ThemeText {
            text: Qt.formatDate(card.controller.viewDate, "MMMM yyyy")
            font.weight: Ui.Theme.fontWeightDemiBold
        }
        Row {
            width: parent.width
            height: 18
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Ui.ThemeText {
                    required property string modelData
                    width: parent.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Ui.Theme.subtleText
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }
        }
        Grid {
            width: parent.width
            height: Math.min(150, parent.parent.height - y - nextEvent.height - parent.spacing)
            columns: 7
            rows: 6
            Repeater {
                model: 42
                delegate: Rectangle {
                    id: dayCell
                    required property int index
                    readonly property date value: new Date(card.firstDay.getFullYear(), card.firstDay.getMonth(), index - card.firstDayOffset + 1)
                    readonly property bool inMonth: value.getMonth() === card.controller.viewDate.getMonth()
                    readonly property bool today: card.controller.dateKey(value) === card.todayKey
                    width: parent.width / 7
                    height: parent.height / 6
                    radius: Ui.Theme.controlRadius
                    color: today ? Ui.Theme.accent : "transparent"
                    Ui.ThemeText {
                        anchors.centerIn: parent
                        text: dayCell.value.getDate()
                        color: dayCell.today ? Ui.Theme.accentText : dayCell.inMonth ? Ui.Theme.text : Ui.Theme.subtleText
                        font.pixelSize: Ui.Theme.fontSizeCaption
                        font.weight: dayCell.today ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
                    }
                    Rectangle {
                        visible: card.controller.hasActivity(dayCell.value) && !dayCell.today
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        width: 3
                        height: 3
                        radius: 2
                        color: Ui.Theme.accent
                    }
                }
            }
        }
        Rectangle {
            id: nextEvent
            width: parent.width
            height: 49
            radius: Ui.Theme.controlRadius
            color: Ui.Theme.surfaceRaised
            border.color: Ui.Theme.border
            Rectangle {
                width: 4
                height: parent.height
                radius: 2
                color: Ui.Theme.accent
            }
            Column {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 8
                anchors.topMargin: 7
                spacing: 2
                Ui.ThemeText {
                    width: parent.width
                    text: String(card.controller.activity.event_count || 0) + " upcoming calendar items"
                    elide: Text.ElideRight
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Ui.ThemeText {
                    text: "Next " + card.eventTime(card.controller.activity.next_event) + "  ·  " + String(card.controller.activity.incomplete_todo_count || 0) + " open todos"
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }
        }
    }

    Ui.ActionArea {
        anchors.fill: parent
        accessibleName: qsTr("Open calendar, agenda and todos")
        onClicked: card.controller.openSection("schedule")
    }
}
