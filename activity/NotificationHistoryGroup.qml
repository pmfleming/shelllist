pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: stack

    required property var group
    required property NotificationController controller
    readonly property NotificationState notificationState: controller.notificationState
    readonly property bool expanded: notificationState.expandedGroups[group.key] === true
    readonly property bool multiple: group.records.length > 1
    readonly property var visibleRecords: expanded ? group.records : group.records.slice(0, 1)
    readonly property int contentMargin: expanded && multiple ? Ui.Theme.spacingSm : 0

    width: ListView.view ? ListView.view.width : 300
    implicitHeight: content.implicitHeight + contentMargin * 2
    radius: Ui.Theme.cardRadius
    color: expanded && multiple ? Ui.Theme.withAlpha(Ui.Theme.surface, 0.72) : "transparent"
    border.width: 1
    border.color: controller.selectedGroupKey === group.key
        ? Ui.Theme.accent : expanded && multiple ? Ui.Theme.border : "transparent"

    function rebuildRecords(): void {
        Ui.NotificationPresentation.syncKeyedModel(recordsModel, visibleRecords.map(function (record) {
            const notification = Ui.NotificationPresentation.notificationFor(record);
            return { key: record.history_id !== undefined ? "history:" + record.history_id
                : "active:" + notification.id, payload: record };
        }));
    }
    onVisibleRecordsChanged: rebuildRecords()
    Component.onCompleted: rebuildRecords()
    ListModel { id: recordsModel; dynamicRoles: true }

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
            clearEnabled: stack.notificationState.isGroupActive(stack.group.key)
            onClearRequested: stack.notificationState.clearNotificationGroup(stack.group.key)
            onExpandedToggled: stack.notificationState.setExpanded(stack.group.key, false)
        }

        Repeater {
            model: recordsModel
            NotificationHistoryRow {
                required property string payload
                record: JSON.parse(payload)
                controller: stack.controller
                width: content.width
                groupCount: stack.group.records.length
                groupedContext: stack.expanded && stack.multiple
                groupToggleVisible: !stack.expanded && stack.multiple
                onGroupToggled: {
                    stack.controller.selectedGroupKey = stack.group.key;
                    stack.notificationState.setExpanded(stack.group.key, true);
                }
            }
        }
    }
}
