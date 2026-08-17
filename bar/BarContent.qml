pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BarPresentation.js" as Presentation

Item {
    id: root

    required property BarController controller
    required property string screenName
    property date now
    readonly property int layoutDensity: Presentation.layoutDensity(width)
    readonly property real centerClearance: Math.max(0, 2 * Math.min(
        width / 2 - workspaceCluster.width - 8,
        width / 2 - statusCluster.width - 8))
    readonly property var toneColors: ({
        text: Ui.Theme.text, muted: Ui.Theme.mutedText, accent: Ui.Theme.accent,
        success: Ui.Theme.active, danger: Ui.Theme.danger, warning: Ui.Theme.warning
    })

    function moduleColor(tone: string): color { return toneColors[tone] || Ui.Theme.text; }

    Rectangle {
        anchors.fill: parent
        color: Ui.Theme.withAlpha(Ui.Theme.window, 0.92)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Ui.Theme.border
        }
    }

    WorkspaceStrip {
        id: workspaceCluster
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        controller: root.controller
        screenName: root.screenName
        layoutDensity: root.layoutDensity
    }

    BarAction {
        id: mediaAction
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: root.controller.activePlayer !== null && root.centerClearance >= 72
        width: Math.min(420, implicitWidth, root.centerClearance)
        horizontalPadding: root.layoutDensity === 0 ? 10 : 6
        text: Presentation.mediaText(root.controller.activePlayer)
        tooltipText: root.controller.activePlayer
            ? [root.controller.activePlayer.artist || root.controller.activePlayer.identity || "",
                root.controller.activePlayer.album || ""].filter(Boolean).join("\n") : ""
        elide: Text.ElideRight
        onPrimaryTriggered: root.controller.mediaOperation("play-pause")
        onSecondaryTriggered: root.controller.mediaOperation("next")
        onMiddleTriggered: root.controller.mediaOperation("previous")
    }

    Row {
        id: statusCluster
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: root.layoutDensity === 0 ? 2 : 0

        BarTray {
            height: parent.height
            layoutDensity: root.layoutDensity
        }

        Repeater {
            model: Presentation.visibleStatusModules(
                root.controller.statusModules(root.now), root.layoutDensity)

            delegate: BarAction {
                required property var modelData

                height: parent.height
                text: Presentation.moduleText(modelData, root.layoutDensity)
                tooltipText: modelData.tooltip
                horizontalPadding: root.layoutDensity === 0 ? 10
                    : root.layoutDensity === 1 ? 7 : 5
                foreground: root.moduleColor(modelData.tone)
                fontWeight: modelData.weight
                interactive: modelData.interactive
                onPrimaryTriggered: root.controller.triggerModuleAction(modelData.primary)
                onSecondaryTriggered: root.controller.triggerModuleAction(modelData.secondary)
                onMiddleTriggered: root.controller.triggerModuleAction(modelData.middle)
                onWheelUp: root.controller.triggerModuleAction(modelData.wheelUp)
                onWheelDown: root.controller.triggerModuleAction(modelData.wheelDown)
            }
        }
    }

    Component.onCompleted: now = new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }
}
