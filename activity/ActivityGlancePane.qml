pragma ComponentBehavior: Bound

import Quickshell
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
    function iconSource(name: string): url {
        return Qt.resolvedUrl("assets/weather/" + name + ".svg");
    }
    function conditionCode(value: var): int {
        const number = Number(value);
        return Number.isFinite(number) ? number : -1;
    }
    function eventTime(event: var): string {
        if (!event)
            return "No upcoming events";
        if (event.all_day)
            return "All day";
        return Qt.formatTime(new Date(event.start_unix_ms), "HH:mm");
    }
    function notificationForGroup(group: var): var {
        const record = group && group.records && group.records.length > 0
            ? group.records[0] : ({});
        return record.notification || record;
    }
    function notificationIconSource(group: var): string {
        const notification = notificationForGroup(group);
        const hints = notification.hints || ({});
        const candidate = String(hints.image_path || notification.app_icon || "");
        if (candidate.startsWith("/"))
            return "file://" + candidate;
        if (candidate.startsWith("file://"))
            return candidate;
        return Quickshell.iconPath(candidate || "dialog-information", "dialog-information");
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
                Row {
                    width: parent.width * 0.38
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    WeatherIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(70, parent.width * 0.48)
                        height: width
                        conditionCode: pane.conditionCode(pane.weather().condition_code)
                        daytime: pane.weather().is_day !== false
                        description: pane.weather().condition || ""
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: pane.temperature()
                            color: Ui.Theme.text
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: 31
                        }
                        Text {
                            text: pane.weather().available
                                ? Math.round(Number(pane.weather().high_c)) + "°  "
                                    + Math.round(Number(pane.weather().low_c)) + "°" : "—"
                            color: Ui.Theme.mutedText
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                    }
                }
            }
            Row {
                id: weatherMeta
                width: parent.width
                height: 20
                spacing: Ui.Theme.spacingMd
                Repeater {
                    model: [
                        { icon: "thermometer", value: pane.weather().available
                            ? Math.round(Number(pane.weather().apparent_temperature_c)) + "°" : "—" },
                        { icon: "raindrop", value: pane.weather().available
                            ? Math.round(Number(pane.weather().precipitation_probability)) + "%" : "—" },
                        { icon: "wind", value: pane.weather().available
                            ? Math.round(Number(pane.weather().wind_speed_kmh)) + " km/h" : "—" }
                    ]
                    delegate: Row {
                        id: glanceMetric
                        required property var modelData
                        height: weatherMeta.height
                        spacing: 3
                        Image {
                            width: 18
                            height: 18
                            source: pane.iconSource(glanceMetric.modelData.icon)
                            fillMode: Image.PreserveAspectFit
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: glanceMetric.modelData.value
                            color: Ui.Theme.mutedText
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                    }
                }
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
        id: notificationCard

        readonly property bool detailMode: pane.controller.detailsOpen
            && pane.controller.detailSection === "notifications"
        readonly property int previewLimit: height >= 230 ? 3 : 2
        readonly property var previewGroups: pane.controller.activeNotificationGroups.slice(
            0, previewLimit)

        width: parent.width
        height: Math.max(170, pane.height - y)
        radius: Ui.Theme.panelRadius
        color: detailMode ? Ui.Theme.selected : Ui.Theme.surface
        border.color: Ui.Theme.border
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingMd
            spacing: Ui.Theme.spacingSm

            Row {
                width: parent.width
                visible: !notificationCard.detailMode
                height: visible ? 28 : 0
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
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅂"
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: Ui.Theme.iconSize
                }
            }

            Repeater {
                model: notificationCard.detailMode ? [] : notificationCard.previewGroups
                delegate: Rectangle {
                    id: notificationPreview
                    required property var modelData
                    readonly property var notification: pane.notificationForGroup(modelData)

                    width: parent.width
                    height: 44
                    radius: Ui.Theme.controlRadius
                    color: Ui.Theme.surfaceRaised
                    border.color: Ui.Theme.border

                    Row {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: Ui.Theme.spacingSm

                        Item {
                            width: 32
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: pane.notificationIconSource(notificationPreview.modelData)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                            Rectangle {
                                visible: notificationPreview.modelData.records.length > 1
                                width: 16
                                height: 16
                                radius: 8
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                color: Ui.Theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: notificationPreview.modelData.records.length > 9
                                        ? "9+" : String(notificationPreview.modelData.records.length)
                                    color: Ui.Theme.accentText
                                    font.family: Ui.Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: Ui.Theme.fontWeightBold
                                }
                            }
                        }

                        Column {
                            width: parent.width - 32 - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                width: parent.width
                                text: notificationPreview.notification.summary
                                    || notificationPreview.modelData.appName
                                color: Ui.Theme.text
                                elide: Text.ElideRight
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeSmall
                                font.weight: Ui.Theme.fontWeightDemiBold
                            }
                            Text {
                                width: parent.width
                                text: notificationPreview.modelData.appName
                                color: Ui.Theme.mutedText
                                elide: Text.ElideRight
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                        }
                    }
                }
            }

            Item {
                visible: notificationCard.detailMode
                    || notificationCard.previewGroups.length === 0
                width: parent.width
                height: visible ? 72 : 0
                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.72)
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: 36
                }
                Rectangle {
                    visible: Number(pane.controller.notifications.count || 0) > 0
                    width: 22
                    height: 22
                    radius: 11
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 19
                    anchors.verticalCenterOffset: -15
                    color: Ui.Theme.accent
                    Text {
                        anchors.centerIn: parent
                        text: pane.controller.notifications.count > 99
                            ? "99+" : String(pane.controller.notifications.count || 0)
                        color: Ui.Theme.accentText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: pane.controller.notifications.count > 99
                            ? 8 : Ui.Theme.fontSizeCaption
                        font.weight: Ui.Theme.fontWeightBold
                    }
                }
            }

            Row {
                width: parent.width
                height: 22
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pane.controller.notifications.dnd ? "󰂛" : ""
                    color: pane.controller.notifications.dnd
                        ? Ui.Theme.warning : Ui.Theme.mutedText
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: Ui.Theme.iconSize
                }
                Text {
                    width: parent.width - x
                    visible: !notificationCard.detailMode
                        && pane.controller.activeNotificationGroups.length
                            > notificationCard.previewGroups.length
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: "+" + String(pane.controller.activeNotificationGroups.length
                        - notificationCard.previewGroups.length)
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: "Open notifications"
            onClicked: pane.controller.openSection("notifications")
        }
    }
}
