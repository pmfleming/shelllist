pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BarPresentation.js" as Presentation

Item {
    id: root

    required property BarController controller
    required property string screenName
    required property int layoutDensity
    readonly property int activeWorkspaceId: Presentation.activeWorkspaceId(
        controller.workspaces, screenName)
    readonly property Item activeButton: {
        activeWorkspaceId;
        workspaceRepeater.count;
        for (let index = 0; index < workspaceRepeater.count; index++) {
            const candidate = workspaceRepeater.itemAt(index);
            // Repeater.itemAt() is typed as Item; every delegate is a WorkspaceButton.
            // qmllint disable missing-property
            if (candidate && candidate.workspaceId === activeWorkspaceId)
                return candidate;
            // qmllint enable missing-property
        }
        return null;
    }

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: 51

    Rectangle {
        id: activeIndicator

        x: root.activeButton ? workspaceRow.x + root.activeButton.x : workspaceRow.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        width: root.activeButton ? root.activeButton.width : 0
        height: root.layoutDensity >= 2 ? 27 : 31
        radius: height / 2
        color: Ui.Theme.mix(Ui.Theme.selected, Ui.Theme.accent, Ui.Theme.dark ? 0.18 : 0.10)
        border.width: 1
        border.color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.68)
        opacity: root.activeButton ? 1 : 0

        Behavior on x {
            enabled: !Ui.Theme.noAnimations
            NumberAnimation {
                duration: Ui.Theme.animationNormal
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            enabled: !Ui.Theme.noAnimations
            NumberAnimation {
                duration: Ui.Theme.animationFast
                easing.type: Ui.Theme.easingStandard
            }
        }
        Behavior on opacity {
            enabled: !Ui.Theme.noAnimations
            NumberAnimation { duration: Ui.Theme.animationFast }
        }
    }

    Row {
        id: workspaceRow

        anchors.fill: parent
        spacing: root.layoutDensity === 0 ? 8 : root.layoutDensity === 1 ? 5 : 2
        leftPadding: root.layoutDensity < 2 ? 10 : 4
        rightPadding: leftPadding

        Repeater {
            id: workspaceRepeater
            model: Presentation.workspaceIds(root.controller.workspaces, root.screenName)

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
