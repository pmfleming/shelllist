pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import Shelllist.Ui as Ui

Item {
    id: root
    property DisplayController controller: null
    Variants {
        model: root.controller && root.controller.uiActive && root.controller.identifyActive ? Quickshell.screens : []
        PanelWindow { // qmllint disable uncreatable-type
            id: window
            required property var modelData
            readonly property int outputIndex: root.controller ? root.controller.outputs.findIndex(function (o) { return o.name === window.modelData.name && !o.disabled; }) : -1
            screen: modelData
            visible: outputIndex >= 0
            color: "transparent"
            implicitWidth: 190
            implicitHeight: 100
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.namespace: "shelllist-display-identify"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; left: true }
            margins { top: 72; left: 24 } // qmllint disable unresolved-type unqualified
            Rectangle {
                anchors.fill: parent
                color: Ui.Theme.window
                radius: Ui.Theme.windowRadius
                border.color: Ui.Theme.accent
                border.width: 2
                Column {
                    anchors.centerIn: parent
                    spacing: Ui.Theme.spacingXs
                    Ui.ThemeText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: window.outputIndex + 1
                        font.pixelSize: 36
                        font.weight: Ui.Theme.fontWeightBold
                        color: Ui.Theme.accent
                    }
                    Ui.ThemeText { anchors.horizontalCenter: parent.horizontalCenter; text: window.modelData.name }
                }
            }
        }
    }
}
