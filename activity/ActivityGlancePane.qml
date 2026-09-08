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
        height: Math.max(88, Math.min(96, pane.height * 0.11))
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.selected
        border.color: Ui.Theme.border
        clip: true

        Item {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingSm

            Item {
                id: weatherHeader
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.right: parent.right
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Local time · Weather"
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↗"
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeHeading
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: "Open Time and Weather"
                    onClicked: pane.controller.requestTimeWeather("weather")
                }
            }

            Item {
                anchors.left: parent.left
                anchors.top: weatherHeader.bottom
                anchors.topMargin: 2
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Item {
                    id: timeSummary
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.round(parent.width * 0.38)

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: Qt.formatTime(pane.now, "HH:mm")
                            color: Ui.Theme.text
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: 26
                            font.weight: Ui.Theme.fontWeightDemiBold
                        }
                        Text {
                            text: Qt.formatDate(pane.now, "ddd, d MMM").toUpperCase()
                            color: Ui.Theme.mutedText
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeCaption
                            font.weight: Ui.Theme.fontWeightDemiBold
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: "Open city times"
                        onClicked: pane.controller.requestTimeWeather("time")
                    }
                }

                Item {
                    anchors.left: timeSummary.right
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    Item {
                        id: weatherVisual
                        anchors.left: parent.left
                        // Match the temperature block, not the taller card body.
                        anchors.top: temperatureSummary.top
                        anchors.bottom: temperatureSummary.bottom
                        width: 54

                        WeatherIcon {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 34
                            height: width
                            conditionCode: pane.conditionCode(pane.weather().condition_code)
                            daytime: pane.weather().is_day !== false
                            description: pane.weather().condition || ""
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            spacing: 2

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 11
                                height: width
                                source: pane.iconSource("raindrop")
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                text: pane.weather().available
                                    ? Math.round(Number(
                                        pane.weather().precipitation_probability)) + "%" : "—"
                                color: Ui.Theme.mutedText
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                        }
                    }

                    Column {
                        id: temperatureSummary
                        anchors.left: weatherVisual.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 76
                        spacing: 0

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: pane.temperature()
                            color: Ui.Theme.text
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: 24
                            font.weight: Ui.Theme.fontWeightDemiBold
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: pane.weather().available
                                ? Math.round(Number(pane.weather().high_c)) + "°  "
                                    + Math.round(Number(pane.weather().low_c)) + "°" : "—"
                            color: Ui.Theme.mutedText
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                    }

                    Column {
                        anchors.left: temperatureSummary.right
                        anchors.leftMargin: Ui.Theme.spacingSm
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Row {
                            spacing: 3
                            Image {
                                width: 15
                                height: 15
                                source: pane.iconSource("thermometer")
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Feels " + (pane.weather().available
                                    ? Math.round(Number(
                                        pane.weather().apparent_temperature_c)) + "°" : "—")
                                color: Ui.Theme.mutedText
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                        }
                        Row {
                            spacing: 3
                            Image {
                                width: 15
                                height: 15
                                source: pane.iconSource("wind")
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: pane.weather().available
                                    ? Math.round(Number(pane.weather().wind_speed_kmh))
                                        + " km/h" : "—"
                                color: Ui.Theme.mutedText
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: "Open city weather"
                        onClicked: pane.controller.requestTimeWeather("weather")
                    }
                }
            }
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
        objectName: "agendaNotificationCard"

        readonly property int previewLimit: Ui.NotificationPresentation.previewCapacity(
            height, Ui.Theme.spacingSm, Ui.Theme.spacingMd)
        readonly property var previewGroups: pane.controller.notificationState.recentNotifications.slice(
            0, previewLimit).map(function (record) {
                return {
                    key: Ui.NotificationPresentation.groupKey(record),
                    appName: Ui.NotificationPresentation.notificationFor(record).app_name || "Notifications",
                    records: [record],
                    tab: record.history_id !== undefined ? "history" : "active"
                };
            })

        width: parent.width
        height: Math.max(170, pane.height - y)
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border
        clip: true

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
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↗"
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.iconSize
                }
            }

            Repeater {
                model: notificationCard.previewGroups
                delegate: Rectangle {
                    id: notificationPreview
                    objectName: "agendaNotificationPreview"
                    required property var modelData
                    readonly property var notification: pane.notificationForGroup(modelData)

                    width: parent.width
                    height: 48
                    radius: Ui.Theme.controlRadius
                    color: previewMouse.containsMouse || activeFocus
                        ? Ui.Theme.selected : Ui.Theme.surfaceRaised
                    border.color: activeFocus ? Ui.Theme.accent : Ui.Theme.border
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Open " + modelData.appName + " notifications: "
                        + String(notification.summary || "")
                    function openGroup(): void {
                        pane.controller.requestNotifications(modelData.key, modelData.tab);
                    }
                    Accessible.onPressAction: openGroup()
                    Keys.onReturnPressed: openGroup()
                    Keys.onSpacePressed: openGroup()

                    MouseArea {
                        id: previewMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notificationPreview.openGroup()
                    }

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
                                    + (notificationPreview.notification.created_unix_ms
                                        ? " · " + Ui.NotificationPresentation.relativeTime(
                                            notificationPreview.notification.created_unix_ms,
                                            pane.now.getTime()) : "")
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
                visible: notificationCard.previewGroups.length === 0
                width: parent.width
                height: visible ? Math.max(0, Math.min(48,
                    parent.height - y - 68 - parent.spacing * 2)) : 0
                clip: true
                Text {
                    anchors.centerIn: parent
                    text: pane.controller.notificationState.historyLoading ? "Loading notifications…"
                        : pane.controller.notificationState.historyError ? "Could not load recent notifications"
                        : pane.controller.notifications.available ? "No recent notifications"
                        : "Notifications unavailable"
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeSmall
                }
            }

            Row {
                width: parent.width
                height: 34
                spacing: Ui.Theme.spacingSm
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DND"
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeSmall
                }
                Ui.ToggleSwitch {
                    objectName: "agendaDnd"
                    height: 34
                    checked: pane.controller.notifications.dnd
                    enabled: pane.controller.notifications.available
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: "Do not disturb"
                    Accessible.checked: checked
                    Accessible.onToggleAction: toggle()
                    onToggled: function (checked) {
                        pane.controller.notificationState.setDndEnabled(checked);
                    }
                }
                NotificationDndDuration {
                    notificationState: pane.controller.notificationState
                }
            }
            ActivityHeaderButton {
                objectName: "agendaNotificationsExpand"
                label: "View all notifications ↗"
                onTriggered: pane.controller.requestNotifications("", "history")
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 28 + Ui.Theme.spacingMd
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Open notifications"
            Accessible.onPressAction: pane.controller.requestNotifications("", "active")
            Keys.onReturnPressed: pane.controller.requestNotifications("", "active")
            Keys.onSpacePressed: pane.controller.requestNotifications("", "active")
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pane.controller.requestNotifications("", "active")
            }
        }
    }
}
