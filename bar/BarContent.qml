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
    function moduleBackground(tone: string): color {
        const foreground = moduleColor(tone);
        const base = Ui.Theme.mix(Ui.Theme.surfaceRaised, foreground,
            tone === "text" || tone === "muted" ? 0.02 : 0.08);
        return Ui.Theme.withAlpha(base, 0.62);
    }

    Rectangle {
        anchors.fill: parent
        color: Ui.Theme.withAlpha(Ui.Theme.window, 0.80)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Ui.Theme.withAlpha(Ui.Theme.window, 0.88) }
            GradientStop { position: 0.5; color: Ui.Theme.withAlpha(Ui.Theme.surface, 0.76) }
            GradientStop { position: 1; color: Ui.Theme.withAlpha(Ui.Theme.window, 0.88) }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.12)
        }

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
        anchors.topMargin: 7
        anchors.bottomMargin: 7
        visible: root.controller.activePlayer !== null && root.centerClearance >= 72
        width: Math.min(420, implicitWidth, root.centerClearance)
        horizontalPadding: root.layoutDensity === 0 ? 12 : 8
        backgroundColor: Ui.Theme.withAlpha(Ui.Theme.mix(Ui.Theme.surfaceRaised,
            Ui.Theme.accent, 0.08), 0.68)
        borderColor: Ui.Theme.withAlpha(Ui.Theme.accent, 0.42)
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
        anchors.topMargin: 7
        anchors.bottomMargin: 7
        spacing: root.layoutDensity === 0 ? 5 : 3

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
                backgroundColor: root.moduleBackground(modelData.tone)
                borderColor: Ui.Theme.withAlpha(root.moduleColor(modelData.tone),
                    modelData.tone === "text" || modelData.tone === "muted" ? 0.16 : 0.34)
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
