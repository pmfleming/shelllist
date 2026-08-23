pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Column {
    id: pane

    required property ActivityController controller
    required property date now

    spacing: Ui.Theme.spacingMd

    function weather(): var {
        return controller.activity.weather || ({ available: false });
    }
    function temperature(): string {
        const value = Number(weather().temperature_c);
        return weather().available && Number.isFinite(value) ? Math.round(value) + "°" : "—";
    }
    function weatherLabel(): string {
        if (!weather().available)
            return weather().error || "Weather unavailable";
        return weather().condition || "Current conditions";
    }
    function eventTime(event: var): string {
        if (!event)
            return "No upcoming events";
        if (event.all_day)
            return "All day";
        return Qt.formatTime(new Date(event.start_unix_ms), "HH:mm");
    }
    Rectangle {
        width: parent.width
        height: Math.max(150, Math.min(190, pane.height * 0.23))
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.selected
        border.color: Ui.Theme.border

        Column {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingMd
            spacing: 3

            Row {
                width: parent.width
                height: 25
                Text {
                    width: parent.width - weatherExpand.width
                    text: "Local time · Weather"
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Text {
                    id: weatherExpand
                    text: "↗"
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeHeading
                }
            }
            Row {
                width: parent.width
                height: parent.height - y - weatherMeta.height
                Column {
                    width: parent.width * 0.62
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: Qt.formatTime(pane.now, "HH:mm")
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: 42
                        font.weight: Ui.Theme.fontWeightRegular
                    }
                    Text {
                        text: Qt.formatDate(pane.now, "dddd, d MMMM").toUpperCase()
                        color: Ui.Theme.mutedText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeCaption
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                }
                Column {
                    width: parent.width * 0.38
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: pane.temperature()
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: 31
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: pane.weatherLabel()
                        color: Ui.Theme.mutedText
                        elide: Text.ElideRight
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                }
            }
            Text {
                id: weatherMeta
                width: parent.width
                text: pane.weather().available
                    ? "Feels " + Math.round(Number(pane.weather().apparent_temperature_c))
                        + "°  ·  H " + Math.round(Number(pane.weather().high_c))
                        + "°  L " + Math.round(Number(pane.weather().low_c)) + "°"
                    : "Open for world clocks and weather details"
                color: Ui.Theme.mutedText
                elide: Text.ElideRight
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pane.controller.openSection("weather")
        }
    }

    Rectangle {
        width: parent.width
        height: Math.max(250, Math.min(320, pane.height * 0.38))
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
                Text {
                    width: parent.width - scheduleExpand.width
                    text: "Calendar · Agenda · Todo    "
                        + String(pane.controller.activity.incomplete_todo_count || 0)
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Text {
                    id: scheduleExpand
                    text: "↗"
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeHeading
                }
            }
            Text {
                text: Qt.formatDate(pane.controller.viewDate, "MMMM yyyy")
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeBody
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Row {
                width: parent.width
                height: 18
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Text {
                        required property string modelData
                        width: parent.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Ui.Theme.subtleText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                }
            }
            Grid {
                width: parent.width
                height: Math.min(150, parent.parent.height - y - nextEvent.height
                    - parent.spacing)
                columns: 7
                rows: 6
                Repeater {
                    model: 42
                    delegate: Rectangle {
                        id: dayCell
                        required property int index
                        readonly property date first: new Date(pane.controller.viewDate.getFullYear(),
                            pane.controller.viewDate.getMonth(), 1)
                        readonly property int offset: (first.getDay() + 6) % 7
                        readonly property date value: new Date(first.getFullYear(), first.getMonth(),
                            index - offset + 1)
                        readonly property bool inMonth: value.getMonth()
                            === pane.controller.viewDate.getMonth()
                        readonly property bool today: pane.controller.dateKey(value)
                            === pane.controller.dateKey(pane.now)
                        width: parent.width / 7
                        height: parent.height / 6
                        radius: Ui.Theme.controlRadius
                        color: today ? Ui.Theme.accent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: dayCell.value.getDate()
                            color: dayCell.today ? Ui.Theme.accentText
                                : dayCell.inMonth ? Ui.Theme.text : Ui.Theme.subtleText
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeCaption
                            font.weight: dayCell.today
                                ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
                        }
                        Rectangle {
                            visible: pane.controller.hasActivity(dayCell.value) && !dayCell.today
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
                    Text {
                        width: parent.width
                        text: String(pane.controller.activity.event_count || 0)
                            + " upcoming calendar items"
                        color: Ui.Theme.text
                        elide: Text.ElideRight
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeSmall
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Text {
                        text: "Next " + pane.eventTime(pane.controller.activity.next_event)
                            + "  ·  " + String(pane.controller.activity.incomplete_todo_count || 0)
                            + " open todos"
                        color: Ui.Theme.mutedText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pane.controller.openSection("schedule")
        }
    }

    Rectangle {
        width: parent.width
        height: Math.max(170, pane.height - y)
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        Column {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingMd
            spacing: Ui.Theme.spacingSm

            Row {
                width: parent.width
                height: 28
                Text {
                    width: parent.width - notificationExpand.width
                    text: "Notifications    "
                        + String(pane.controller.notifications.count || 0)
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Text {
                    id: notificationExpand
                    text: "↗"
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeHeading
                }
            }
            Row {
                id: notificationMetrics
                width: parent.width
                height: 78
                spacing: Ui.Theme.spacingSm
                Repeater {
                    model: [
                        { label: "Active", value: String(pane.controller.notifications.count || 0) },
                        { label: "Applications", value: String(pane.controller.notificationGroups.length) },
                        { label: "History", value: String(pane.controller.notificationHistory.length) }
                    ]
                    delegate: Rectangle {
                        id: notificationMetric
                        required property var modelData
                        width: (notificationMetrics.width - notificationMetrics.spacing * 2) / 3
                        height: parent.height
                        radius: Ui.Theme.controlRadius
                        color: Ui.Theme.surfaceRaised
                        border.color: Ui.Theme.border
                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 5
                            Text {
                                text: notificationMetric.modelData.label
                                color: Ui.Theme.mutedText
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                            Text {
                                text: notificationMetric.modelData.value
                                color: Ui.Theme.text
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeDisplay
                                font.weight: Ui.Theme.fontWeightDemiBold
                            }
                        }
                    }
                }
            }
            Text {
                width: parent.width
                text: pane.controller.notifications.dnd
                    ? "Do Not Disturb is on" : "Do Not Disturb is off"
                color: pane.controller.notifications.dnd
                    ? Ui.Theme.warning : Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
            Text {
                width: parent.width
                text: "Open grouped history, actions, replies and filters  ›"
                color: Ui.Theme.accent
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pane.controller.openSection("notifications")
        }
    }
}
