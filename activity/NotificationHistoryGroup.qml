pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: stack

    required property var group
    required property ActivityController controller
    property bool expanded: false
    readonly property var visibleRecords: expanded ? group.records : group.records.slice(0, 1)

    width: ListView.view ? ListView.view.width : 300
    implicitHeight: content.implicitHeight + Ui.Theme.spacingSm * 2
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.withAlpha(Ui.Theme.surface, 0.72)
    border.color: Ui.Theme.border

    Column {
        id: content

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Ui.Theme.spacingSm
        }
        spacing: Ui.Theme.spacingSm

        Ui.NotificationStackHeader {
            width: parent.width
            appName: stack.group.appName
            count: stack.group.records.length
            expanded: stack.expanded
            clearEnabled: stack.controller.isNotificationGroupActive(stack.group.key)
            onClearRequested: stack.controller.clearNotificationGroup(stack.group.key)
            onExpandedToggled: stack.expanded = !stack.expanded
        }

        Repeater {
            model: stack.visibleRecords
            NotificationHistoryRow {
                required property var modelData
                record: modelData
                controller: stack.controller
                width: content.width
            }
        }
    }
}
