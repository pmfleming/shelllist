pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: pane

    required property ActivityController controller

    function eventTime(event: var): string {
        if (event.all_day)
            return "All day";
        return Qt.formatTime(new Date(event.start_unix_ms), "HH:mm") + "–"
            + Qt.formatTime(new Date(event.end_unix_ms), "HH:mm");
    }

    height: parent.height
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border

    Column {
        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingMd
        spacing: Ui.Theme.spacingSm
        Text {
            text: Qt.formatDate(pane.controller.selectedDate, "dddd, d MMMM")
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeHeading
            font.weight: Ui.Theme.fontWeightDemiBold
        }
        Text {
            visible: pane.controller.selectedEvents.length === 0
            text: pane.controller.rangeLoading ? "Loading events…" : "No events"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
        }
        ListView {
            width: parent.width
            height: parent.height - y
            spacing: Ui.Theme.spacingSm
            clip: true
            model: pane.controller.selectedEvents
            delegate: Rectangle {
                id: eventRow
                required property var modelData
                width: ListView.view.width
                height: Math.max(66, eventTitle.implicitHeight + 34)
                radius: Ui.Theme.cardRadius
                color: Ui.Theme.surfaceRaised
                border.color: Ui.Theme.border
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 5
                    radius: 3
                    color: eventRow.modelData.color || Ui.Theme.accent
                }
                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 10
                    anchors.topMargin: 9
                    anchors.bottomMargin: 9
                    spacing: 3
                    Text {
                        id: eventTitle
                        width: parent.width
                        text: eventRow.modelData.title || "Untitled event"
                        color: Ui.Theme.text
                        elide: Text.ElideRight
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeLabel
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Text {
                        width: parent.width
                        text: pane.eventTime(eventRow.modelData) + "  ·  "
                            + (eventRow.modelData.calendar_name || "Calendar")
                        color: Ui.Theme.mutedText
                        elide: Text.ElideRight
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeSmall
                    }
                    Text {
                        visible: (eventRow.modelData.location || "").length > 0
                        width: parent.width
                        text: eventRow.modelData.location || ""
                        color: Ui.Theme.mutedText
                        elide: Text.ElideRight
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeSmall
                    }
                }
            }
        }
    }
}
