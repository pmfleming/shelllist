pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import Quickshell

Rectangle {
    id: notificationCard
    required property ActivityController controller
    required property date now

    function notificationForGroup(group: var): var {
        const record = group && group.records && group.records.length > 0 ? group.records[0] : ({});
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
    objectName: "agendaNotificationCard"

    readonly property int previewLimit: Ui.NotificationPresentation.previewCapacity(height, Ui.Theme.spacingSm, Ui.Theme.spacingMd)
    readonly property var previewGroups: notificationCard.controller.notificationState.recentNotifications.slice(0, previewLimit).map(function (record) {
        return {
            key: Ui.NotificationPresentation.groupKey(record),
            appName: Ui.NotificationPresentation.notificationFor(record).app_name || "Notifications",
            records: [record],
            tab: record.history_id !== undefined ? "history" : "active"
        };
    })

    width: parent.width
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
            Ui.ThemeText {
                width: parent.width - notificationExpand.width
                text: "Notifications    " + String(notificationCard.controller.notifications.count || 0)
                font.pixelSize: Ui.Theme.fontSizeLabel
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Ui.ThemeText {
                id: notificationExpand
                anchors.verticalCenter: parent.verticalCenter
                text: "↗"
                color: Ui.Theme.accent
                font.pixelSize: Ui.Theme.iconSize
            }
        }

        Repeater {
            model: notificationCard.previewGroups
            delegate: Rectangle {
                id: notificationPreview
                objectName: "agendaNotificationPreview"
                required property var modelData
                readonly property var notification: notificationCard.notificationForGroup(modelData)

                width: parent.width
                height: 48
                radius: Ui.Theme.controlRadius
                color: previewMouse.containsMouse || activeFocus ? Ui.Theme.selected : Ui.Theme.surfaceRaised
                border.color: activeFocus ? Ui.Theme.accent : Ui.Theme.border
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Open " + modelData.appName + " notifications: " + String(notification.summary || "")
                function openGroup(): void {
                    notificationCard.controller.requestNotifications(modelData.key, modelData.tab);
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
                            source: notificationCard.notificationIconSource(notificationPreview.modelData)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }

                    Column {
                        width: parent.width - 32 - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Ui.ThemeText {
                            width: parent.width
                            text: notificationPreview.notification.summary || notificationPreview.modelData.appName
                            elide: Text.ElideRight
                            font.pixelSize: Ui.Theme.fontSizeSmall
                            font.weight: Ui.Theme.fontWeightDemiBold
                        }
                        Ui.ThemeText {
                            width: parent.width
                            text: notificationPreview.modelData.appName + (notificationPreview.notification.created_unix_ms ? " · " + Ui.NotificationPresentation.relativeTime(notificationPreview.notification.created_unix_ms, notificationCard.now.getTime()) : "")
                            color: Ui.Theme.mutedText
                            elide: Text.ElideRight
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                    }
                }
            }
        }

        Item {
            visible: notificationCard.previewGroups.length === 0
            width: parent.width
            height: visible ? Math.max(0, Math.min(48, parent.height - y - 68 - parent.spacing * 2)) : 0
            clip: true
            Ui.ThemeText {
                anchors.centerIn: parent
                text: notificationCard.controller.notificationState.historyLoading ? "Loading notifications…" : notificationCard.controller.notificationState.historyError ? "Could not load recent notifications" : notificationCard.controller.notifications.available ? "No recent notifications" : "Notifications unavailable"
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }

        Row {
            width: parent.width
            height: 34
            spacing: Ui.Theme.spacingSm
            Ui.ThemeText {
                anchors.verticalCenter: parent.verticalCenter
                text: "DND"
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
            Ui.ToggleSwitch {
                objectName: "agendaDnd"
                height: 34
                checked: notificationCard.controller.notifications.dnd
                enabled: notificationCard.controller.notifications.available
                Accessible.role: Accessible.CheckBox
                Accessible.name: qsTr("Do not disturb")
                Accessible.checked: checked
                Accessible.onToggleAction: toggle()
                onToggled: function (checked) {
                    notificationCard.controller.notificationState.setDndEnabled(checked);
                }
            }
            NotificationDndDuration {
                notificationState: notificationCard.controller.notificationState
            }
        }
        ActivityHeaderButton {
            objectName: "agendaNotificationsExpand"
            label: "View all notifications ↗"
            onTriggered: notificationCard.controller.requestNotifications("", "history")
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 28 + Ui.Theme.spacingMd
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Open notifications")
        Accessible.onPressAction: notificationCard.controller.requestNotifications("", "active")
        Keys.onReturnPressed: notificationCard.controller.requestNotifications("", "active")
        Keys.onSpacePressed: notificationCard.controller.requestNotifications("", "active")
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: notificationCard.controller.requestNotifications("", "active")
        }
    }
}
