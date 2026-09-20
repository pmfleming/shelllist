pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: workspace
    required property DisplayController controller
    objectName: "displayLayoutWorkspace"
    revealFocusedControl: true
    GridLayout {
        width: workspace.width
        columns: width >= 740 ? 2 : 1
        height: columns === 2 ? Math.max(implicitHeight, workspace.height) : implicitHeight
        columnSpacing: Ui.Theme.spacingLg
        rowSpacing: Ui.Theme.spacingMd
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 620
            DisplayCanvas {
                id: diagram
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 180
                Layout.preferredHeight: workspace.width >= 740 ? 360 : 210
                controller: workspace.controller
                editing: true
            }
            Ui.ThemeText {
                Layout.fillWidth: true
                text: "[ ]   ·   ← ↑ ↓ →  16 px   ·   Shift  1 px   ·   Ctrl  64 px"
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }
        DisplayInspector {
            Layout.fillWidth: true
            Layout.preferredWidth: 320
            Layout.alignment: Qt.AlignTop
            controller: workspace.controller
        }
    }
    Connections {
        target: workspace.controller
        function onEditorFocusRequested(): void { diagram.forceActiveFocus(); }
        function onFocusSearchRequested(): void { diagram.forceActiveFocus(); }
    }
    Component.onCompleted: if (controller.uiActive) diagram.forceActiveFocus()
}
