pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
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
    readonly property bool overflow: groups.implicitWidth > barSurface.width - 16
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
        radius: 20
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
            contentWidth: Math.max(width, groups.implicitWidth)
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width
            clip: true
            RowLayout {
                id: groups
                width: viewport.contentWidth
                height: viewport.height
                spacing: root.layoutDensity >= 2 ? 2 : 6
                WorkspaceStrip {
                    objectName: "barWorkspaces"
                    Layout.preferredWidth: Math.max(32, Math.min(implicitWidth, root.width * 0.27))
                    Layout.fillHeight: true
                    controller: root.controller
                    screenName: root.screenName
                    layoutDensity: root.layoutDensity
                }
                MediaChip {
                    objectName: "barMedia"
                    Layout.preferredWidth: implicitWidth
                    Layout.fillHeight: true
                    controller: root.controller
                    layoutDensity: root.layoutDensity
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: Core.KeyedListModel {
                        values: root.statusDescriptors
                        function equivalent(left: var, right: var): bool { return Presentation.statusModuleEqual(left, right); }
                    }
                    delegate: BarAction {
                        required property var resultData
                        objectName: "bar:" + resultData.id
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        text: resultData.text
                        accessibleName: resultData.tooltip
                        horizontalPadding: 4
                        foreground: root.toneColors[resultData.tone] || Ui.Theme.text
                        onPrimaryTriggered: root.controller.triggerModuleAction(resultData.primary)
                        onSecondaryTriggered: root.controller.triggerModuleAction(resultData.secondary)
                        onMiddleTriggered: root.controller.triggerModuleAction(resultData.middle)
                    }
                }
                BarTray {
                    objectName: "barTray"
                    Layout.preferredWidth: implicitWidth
                    Layout.fillHeight: true
                    controller: root.controller
                    layoutDensity: root.layoutDensity
                }
                BarAction {
                    objectName: "barClock"
                    readonly property var descriptor: Presentation.clockModule(root.now, root.controller.timezone)
                    Layout.preferredWidth: implicitWidth
                    Layout.fillHeight: true
                    text: Presentation.moduleText(descriptor, root.layoutDensity)
                    symbolic: false
                    accessibleName: descriptor.tooltip
                    horizontalPadding: 6
                    onPrimaryTriggered: root.controller.openTimeWeather("time")
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
        icon: viewport.atXEnd ? "󰁍" : "󰅂"
        accessibleName: viewport.atXEnd ? qsTr("Scroll bar to beginning") : qsTr("Scroll bar forward")
        backgroundColor: Ui.Theme.surface
        border.width: 0
        onClicked: viewport.contentX = viewport.atXEnd ? 0 : Math.min(viewport.contentWidth - viewport.width, viewport.contentX + viewport.width / 2)
    }
    Component.onCompleted: updateClock()
    Timer { id: clockTimer; repeat: false; onTriggered: root.updateClock() }
}
