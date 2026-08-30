pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: pane

    required property ActivityController controller

    radius: Ui.Theme.panelRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border

    Column {
        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingMd
        spacing: Ui.Theme.spacingSm

        Row {
            width: parent.width
            height: 42
            spacing: Ui.Theme.spacingSm

            Row {
                width: parent.width - dndButton.width - clearButton.width
                    - parent.spacing * 2
                height: parent.height
                spacing: 6
                Accessible.role: Accessible.StaticText
                Accessible.name: String(pane.controller.notifications.count || 0)
                    + " active notifications, "
                    + String(pane.controller.notificationHistory.length) + " in history"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: Ui.Theme.iconSize
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(pane.controller.notifications.count || 0)
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰋚"
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: Ui.Theme.iconSize
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(pane.controller.notificationHistory.length)
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                }
            }
            Ui.DropDownList {
                id: dndButton
                width: 122
                height: 36
                value: pane.controller.notifications.dnd ? -1 : 0
                options: [
                    { value: -1, label: Ui.NotificationPresentation.dndLabel(
                        pane.controller.notifications, Date.now()) },
                    { value: 0, label: "DND off" },
                    { value: 30, label: "For 30 min" },
                    { value: 60, label: "For 1 hour" },
                    { value: 120, label: "For 2 hours" },
                    { value: 480, label: "For 8 hours" }
                ]
                onSelected: function (minutes) {
                    if (minutes >= 0)
                        pane.controller.setDndForMinutes(minutes);
                }
            }
            Ui.FlatIconButton {
                id: clearButton
                width: 34
                height: 34
                icon: "󰩹"
                enabled: pane.controller.notificationHistory.length > 0
                accessibleName: "Clear all notifications"
                toolTip: accessibleName
                onClicked: pane.controller.clearNotifications()
            }
        }

        Row {
            width: parent.width
            height: 34
            spacing: Ui.Theme.spacingSm
            Repeater {
                model: ["All", "Active", "Calendar", "Messages", "System"]
                ActivityHeaderButton {
                    required property string modelData
                    label: modelData
                    checked: pane.controller.notificationFilter === modelData
                    onTriggered: pane.controller.notificationFilter = modelData
                }
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
            model: pane.controller.filteredNotificationGroups
            delegate: NotificationHistoryGroup {
                required property var modelData
                group: modelData
                controller: pane.controller
            }
        }

        Row {
            id: historyFooter
            width: parent.width
            height: 34
            spacing: Ui.Theme.spacingSm
            Ui.FlatIconButton {
                width: 34
                height: 34
                icon: "󰑐"
                enabled: !pane.controller.notificationHistoryLoading
                accessibleName: "Refresh notification history"
                toolTip: accessibleName
                onClicked: pane.controller.reloadNotificationHistory()
            }
            Ui.FlatIconButton {
                width: 34
                height: 34
                icon: "󰅀"
                enabled: pane.controller.notificationHistoryHasMore
                    && !pane.controller.notificationHistoryLoading
                accessibleName: "Load more notification history"
                toolTip: accessibleName
                onClicked: pane.controller.loadMoreNotificationHistory()
            }
        }
    }
}
