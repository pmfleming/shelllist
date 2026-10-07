pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Core as Core
import "BarStatusPresentation.js" as Presentation

Item {
    id: root
    required property BarController controller
    required property string screenName
    property date now: new Date()
    readonly property alias visualSurface: barSurface
    readonly property int layoutDensity: Presentation.layoutDensity(width)
    readonly property int groupGap: layoutDensity >= 2 ? 8 : 16
    readonly property real minimumContentWidth: workspaces.width + media.implicitWidth + status.implicitWidth + groupGap * 2
    readonly property bool overflow: minimumContentWidth > barSurface.width - 16
    readonly property var statusDescriptors: controller.statusModules(now).filter(module => module.id !== "clock")
    readonly property var toneColors: ({text: Ui.Theme.text, muted: Ui.Theme.mutedText,
        accent: Ui.Theme.accent, success: Ui.Theme.active, danger: Ui.Theme.danger, warning: Ui.Theme.warning})
    function updateClock(): void {
        now = new Date();
        clockTimer.interval = Presentation.nextMinuteDelay(now.getTime());
        clockTimer.restart();
    }
    Rectangle {
        id: barSurface
        anchors.fill: parent
        anchors.margins: 6
        radius: 16
        color: Ui.Theme.withAlpha(Ui.Theme.surface, 0.94)
        border.width: 1
        border.color: Ui.Theme.border
        clip: true
        Flickable {
            id: viewport
            objectName: "barOverflowViewport"
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: root.overflow ? overflowButton.width + 6 : 8
            contentWidth: Math.max(width, root.minimumContentWidth)
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width
            clip: true
            // Density never removes transport. If the three groups cannot fit,
            // the existing overflow route scrolls this complete control strip.
            Item {
                id: groups
                width: viewport.contentWidth
                height: viewport.height
                WorkspaceStrip {
                    id: workspaces
                    objectName: "barWorkspaces"
                    width: Math.max(32, Math.min(implicitWidth, root.width * 0.27))
                    height: parent.height
                    controller: root.controller
                    screenName: root.screenName
                    layoutDensity: root.layoutDensity
                }
                MediaChip {
                    id: media
                    objectName: "barMedia"
                    // True center when possible; only yield to the measured
                    // edge groups when they would otherwise collide.
                    x: Math.max(workspaces.width + root.groupGap,
                        Math.min((groups.width - width) / 2, status.x - root.groupGap - width))
                    width: implicitWidth
                    height: parent.height
                    controller: root.controller
                }
                Row {
                    id: status
                    objectName: "barStatusGroup"
                    x: groups.width - width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.layoutDensity >= 2 ? 2 : 4
                    Repeater {
                        model: Core.KeyedListModel {
                            values: root.statusDescriptors
                            function equivalent(left: var, right: var): bool { return Presentation.statusModuleEqual(left, right); }
                        }
                        delegate: Row {
                            id: statusItem
                            required property var resultData
                            spacing: 6
                            height: 32
                            Rectangle {
                                width: 1
                                height: 18
                                anchors.verticalCenter: parent.verticalCenter
                                color: Ui.Theme.border
                                visible: statusItem.resultData.id === "battery"
                            }
                            BarAction {
                                id: action
                                objectName: "bar:" + statusItem.resultData.id
                                width: statusItem.resultData.id === "battery" ? 42 : 32
                                height: 32
                                radius: 9
                                iconSize: 18
                                text: statusItem.resultData.id === "battery" ? "" : statusItem.resultData.text
                                accessibleName: (statusItem.resultData.id === "battery" && Presentation.batteryKnown(root.controller.battery)
                                    ? qsTr("Battery") + ". " : "") + statusItem.resultData.tooltip
                                foreground: root.toneColors[statusItem.resultData.tone] || Ui.Theme.text
                                onPrimaryTriggered: root.controller.triggerModuleAction(statusItem.resultData.primary)
                                onSecondaryTriggered: root.controller.triggerModuleAction(statusItem.resultData.secondary)
                                onMiddleTriggered: root.controller.triggerModuleAction(statusItem.resultData.middle)
                                Loader {
                                    anchors.centerIn: parent
                                    active: statusItem.resultData.id === "battery"
                                    sourceComponent: BarBatteryGauge {
                                        battery: root.controller.battery
                                        foreground: action.foreground
                                    }
                                }
                            }
                        }
                    }
                    BarTray {
                        objectName: "barTray"
                        width: implicitWidth
                        height: 32
                        controller: root.controller
                    }
                    Rectangle {
                        width: 1
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        color: Ui.Theme.border
                    }
                    BarClockButton {
                        objectName: "barClockAction"
                        width: implicitWidth
                        height: 32
                        now: root.now
                        timezone: root.controller.timezone
                        layoutDensity: root.layoutDensity
                        onPrimaryTriggered: root.controller.openTimeWeather("time")
                    }
                }
            }
        }
    }
    Ui.FlatIconButton {
        id: overflowButton
        objectName: "barOverflowButton"
        anchors.right: barSurface.right
        anchors.rightMargin: 3
        anchors.verticalCenter: barSurface.verticalCenter
        width: 32
        height: 32
        visible: root.overflow
        activeFocusOnTab: false
        browseIndicatorVisible: false
        icon: viewport.atXEnd ? "󰁍" : "󰅂"
        accessibleName: viewport.atXEnd ? qsTr("Scroll bar to beginning") : qsTr("Scroll bar forward")
        backgroundColor: Ui.Theme.surface
        border.width: 0
        onClicked: viewport.contentX = viewport.atXEnd ? 0 : Math.min(viewport.contentWidth - viewport.width, viewport.contentX + viewport.width / 2)
    }
    Component.onCompleted: updateClock()
    Timer { id: clockTimer; repeat: false; onTriggered: root.updateClock() }
}
