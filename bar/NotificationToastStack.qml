pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: stack

    required property var group
    required property BarController controller
    property bool expanded: false
    readonly property var visibleNotifications: expanded ? group.records : group.records.slice(0, 1)

    width: 390
    implicitHeight: content.implicitHeight + (group.records.length > 1 ? Ui.Theme.spacingSm * 2 : 0)
    radius: Ui.Theme.panelRadius
    color: group.records.length > 1 ? Ui.Theme.withAlpha(Ui.Theme.surface, 0.94) : "transparent"
    border.width: group.records.length > 1 ? 1 : 0
    border.color: Ui.Theme.border

    Column {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: stack.group.records.length > 1 ? Ui.Theme.spacingSm : 0
        }
        spacing: Ui.Theme.spacingSm

        Ui.NotificationStackHeader {
            width: parent.width
            visible: stack.group.records.length > 1
            height: visible ? 30 : 0
            appName: stack.group.appName
            count: stack.group.records.length
            expanded: stack.expanded
            onClearRequested: stack.controller.clearNotificationGroup(stack.group.key)
            onExpandedToggled: stack.expanded = !stack.expanded
        }

        Repeater {
            model: stack.visibleNotifications
            NotificationToastCard {
                required property var modelData
                notification: modelData
                controller: stack.controller
                width: content.width
            }
        }
    }
}
