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
            height: parent.height - y
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
    }
}
