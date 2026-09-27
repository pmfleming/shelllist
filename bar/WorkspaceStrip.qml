pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BarWorkspacePresentation.js" as Presentation

Item {
    id: root

    required property BarController controller
    required property string screenName
    required property int layoutDensity
    readonly property var workspaceIds: Presentation.workspaceIds(controller.workspaces, screenName)
    readonly property int activeWorkspaceIndex: Presentation.activeWorkspaceIndex(controller.workspaces, screenName)
    readonly property int workspaceButtonWidth: layoutDensity >= 2 ? 23 : 27

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: 51

    Rectangle {
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, parent.width - 8)
        height: 37
        radius: 0
        color: Ui.Theme.barGroupBackground
        border.width: 1
        border.color: Ui.Theme.barGroupBorder
    }

    Rectangle {
        x: workspaceRow.leftPadding + Math.max(0, root.activeWorkspaceIndex) * (root.workspaceButtonWidth + workspaceRow.spacing)
        anchors.verticalCenter: parent.verticalCenter
        width: root.activeWorkspaceIndex >= 0 ? root.workspaceButtonWidth : 0
        height: root.layoutDensity >= 2 ? 27 : 31
        radius: 0
        color: Ui.Theme.mix(Ui.Theme.selected, Ui.Theme.accent, Ui.Theme.dark ? 0.18 : 0.10)
        border.width: 1
        border.color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.68)
        opacity: root.activeWorkspaceIndex >= 0 ? 1 : 0

        Ui.InteractiveBehavior on x {
            duration: Ui.Theme.animationNormal
        }
        Ui.InteractiveBehavior on width {
            duration: Ui.Theme.animationFast
            easingType: Ui.Theme.easingStandard
        }
        Ui.InteractiveBehavior on opacity {
            duration: Ui.Theme.animationFast
            easingType: Easing.Linear
        }
    }

    Row {
        id: workspaceRow

        anchors.fill: parent
        spacing: root.layoutDensity === 0 ? 8 : root.layoutDensity === 1 ? 5 : 2
        leftPadding: root.layoutDensity < 2 ? 10 : 4
        rightPadding: leftPadding

        Repeater {
            model: root.workspaceIds

            delegate: WorkspaceButton {
                required property int modelData
                controller: root.controller
                screenName: root.screenName
                workspaceId: modelData
                compact: root.layoutDensity >= 2
            }
        }
    }
}
