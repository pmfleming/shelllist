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
        columns: workspace.controller.arrangementOpen && width >= 740 ? 2 : 1
        height: columns === 2 ? Math.max(implicitHeight, workspace.height) : implicitHeight
        columnSpacing: Ui.Theme.spacingLg
        rowSpacing: Ui.Theme.spacingMd
        ColumnLayout {
            visible: workspace.controller.arrangementOpen
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
            RowLayout {
                Layout.fillWidth: true
                Ui.ThemeText {
                    Layout.fillWidth: true
                    text: "[ ]   ·   ← ↑ ↓ →  16 px   ·   Shift  1 px   ·   Ctrl  64 px"
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                }
                Ui.FlatIconButton {
                    Layout.preferredWidth: Ui.Theme.controlHeight
                    Layout.preferredHeight: Ui.Theme.controlHeight
                    icon: "󰅖"
                    accessibleName: qsTr("Hide arrangement canvas")
                    toolTip: accessibleName
                    onClicked: {
                        workspace.controller.arrangementOpen = false;
                        inspector.focusFirstControl();
                    }
                }
            }
        }
        DisplayInspector {
            id: inspector
            Layout.fillWidth: true
            Layout.preferredWidth: 320
            Layout.alignment: Qt.AlignTop
            controller: workspace.controller
        }
    }
    Connections {
        target: workspace.controller
        function onEditorFocusRequested(): void {
            if (!workspace.visible)
                return;
            if (workspace.controller.arrangementOpen)
                diagram.forceActiveFocus();
            else
                inspector.focusFirstControl();
        }
    }
    Component.onCompleted: if (controller.uiActive && controller.arrangementOpen && visible)
        diagram.forceActiveFocus()
}
