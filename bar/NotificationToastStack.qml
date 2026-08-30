pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Item {
    id: stack

    required property var group
    required property BarController controller
    readonly property bool stacked: group.records.length > 1
    readonly property int peekDepth: stacked ? 8 : 0

    width: 390
    implicitHeight: toastCard.implicitHeight + peekDepth

    Rectangle {
        visible: stack.stacked
        width: parent.width - 16
        height: toastCard.implicitHeight
        x: 8
        y: 8
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.62)
        border.color: Ui.Theme.border
    }

    Rectangle {
        visible: stack.stacked
        width: parent.width - 8
        height: toastCard.implicitHeight
        x: 4
        y: 4
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.82)
        border.color: Ui.Theme.border
    }

    NotificationToastCard {
        id: toastCard
        notification: stack.group.records[0]
        controller: stack.controller
        width: parent.width
        groupCount: stack.group.records.length
        breakoutVisible: stack.stacked
        onBreakoutRequested: stack.controller.openNotificationCenter()
    }
}
