pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: stack

    required property var group
    required property ActivityController controller
    property bool expanded: false
    readonly property bool multiple: group.records.length > 1
    readonly property var visibleRecords: expanded ? group.records : group.records.slice(0, 1)
    readonly property int contentMargin: expanded && multiple ? Ui.Theme.spacingSm : 0

    width: ListView.view ? ListView.view.width : 300
    implicitHeight: content.implicitHeight + contentMargin * 2
    radius: Ui.Theme.cardRadius
    color: expanded && multiple ? Ui.Theme.withAlpha(Ui.Theme.surface, 0.72) : "transparent"
    border.width: expanded && multiple ? 1 : 0
    border.color: Ui.Theme.border

    Behavior on implicitHeight {
        enabled: !Ui.Theme.noAnimations
        NumberAnimation {
            duration: Ui.Theme.animationNormal
            easing.type: Ui.Theme.easingStandard
        }
    }

    Column {
        id: content

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: stack.contentMargin
        }
        spacing: Ui.Theme.spacingSm

        Ui.NotificationStackHeader {
            width: parent.width
            visible: stack.expanded && stack.multiple
            height: visible ? 30 : 0
            appName: stack.group.appName
            count: stack.group.records.length
            expanded: stack.expanded
            clearEnabled: stack.controller.isNotificationGroupActive(stack.group.key)
            onClearRequested: stack.controller.clearNotificationGroup(stack.group.key)
            onExpandedToggled: stack.expanded = false
        }

        Repeater {
            model: stack.visibleRecords
            NotificationHistoryRow {
                required property var modelData
                record: modelData
                controller: stack.controller
                width: content.width
                groupCount: stack.group.records.length
                groupedContext: stack.expanded && stack.multiple
                groupToggleVisible: !stack.expanded && stack.multiple
                onGroupToggled: stack.expanded = true
            }
        }
    }
}
