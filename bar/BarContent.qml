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
    readonly property real leftExtent: activeWindowChip.visible
        ? activeWindowChip.x + activeWindowChip.width : workspaceCluster.width
    readonly property real centerClearance: Math.max(0, 2 * Math.min(
        width / 2 - leftExtent - 8,
        width / 2 - statusCluster.width - 8))
    readonly property var toneColors: ({
        text: Ui.Theme.text, muted: Ui.Theme.mutedText, accent: Ui.Theme.accent,
        success: Ui.Theme.active, danger: Ui.Theme.danger, warning: Ui.Theme.warning
    })
    readonly property var statusDescriptors: Presentation.visibleStatusModules(
        controller.statusModules(now), layoutDensity)

    function moduleColor(tone: string): color { return toneColors[tone] || Ui.Theme.text; }
    function neutralTone(tone: string): bool { return ["text", "muted"].includes(tone); }
    function moduleBackground(tone: string): color {
        const foreground = moduleColor(tone);
        const base = Ui.Theme.mix(Ui.Theme.surfaceRaised, foreground,
            neutralTone(tone) ? 0.02 : 0.08);
        return Ui.Theme.withAlpha(base, 0.62);
    }
    function rebuildStatusModel(): void {
        statusModel.clear();
        for (let index = 0; index < statusDescriptors.length; index++)
            statusModel.append({ descriptor: statusDescriptors[index] });
    }
    function syncStatusModel(): void {
        if (statusModel.count !== statusDescriptors.length) {
            rebuildStatusModel();
            return;
        }
        for (let index = 0; index < statusDescriptors.length; index++) {
            if (statusModel.get(index).descriptor.id !== statusDescriptors[index].id) {
                rebuildStatusModel();
                return;
            }
        }
        for (let index = 0; index < statusDescriptors.length; index++) {
            const descriptor = statusDescriptors[index];
            if (!Presentation.statusModuleEqual(statusModel.get(index).descriptor, descriptor))
                statusModel.setProperty(index, "descriptor", descriptor);
        }
    }
    function updateClock(): void {
        now = new Date();
        clockTimer.interval = Presentation.nextMinuteDelay(now.getTime());
        clockTimer.restart();
    }

    onStatusDescriptorsChanged: syncStatusModel()

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

    ActiveWindowChip {
        id: activeWindowChip

        anchors.left: workspaceCluster.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        controller: root.controller
        screenName: root.screenName
        layoutDensity: root.layoutDensity
    }

    MediaChip {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 7
        anchors.bottomMargin: 7
        visible: root.controller.activePlayer !== null && root.centerClearance >= 150
        width: Math.min(implicitWidth, root.centerClearance)
        controller: root.controller
        layoutDensity: root.layoutDensity
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
            model: ListModel {
                id: statusModel
                dynamicRoles: true
            }

            delegate: BarAction {
                required property var descriptor

                height: parent.height
                text: Presentation.moduleText(descriptor, root.layoutDensity)
                horizontalPadding: root.layoutDensity === 0 ? 10
                    : root.layoutDensity === 1 ? 7 : 5
                foreground: root.moduleColor(descriptor.tone)
                backgroundColor: root.moduleBackground(descriptor.tone)
                borderColor: Ui.Theme.withAlpha(root.moduleColor(descriptor.tone),
                    root.neutralTone(descriptor.tone) ? 0.16 : 0.34)
                fontWeight: descriptor.weight
                interactive: descriptor.interactive
                onPrimaryTriggered: root.controller.triggerModuleAction(descriptor.primary)
                onSecondaryTriggered: root.controller.triggerModuleAction(descriptor.secondary)
                onMiddleTriggered: root.controller.triggerModuleAction(descriptor.middle)
                onWheelUp: root.controller.triggerModuleAction(descriptor.wheelUp)
                onWheelDown: root.controller.triggerModuleAction(descriptor.wheelDown)
            }
        }
    }

    Component.onCompleted: {
        updateClock();
        syncStatusModel();
    }
    Timer {
        id: clockTimer
        repeat: false
        onTriggered: root.updateClock()
    }
}
