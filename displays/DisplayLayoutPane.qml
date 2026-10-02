pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: workspace
    required property DisplayController controller
    objectName: "displayLayoutWorkspace"
    viewMemory: controller.viewMemory
    memoryTab: "settings"
    revealFocusedControl: true

    DisplayInspector {
        id: inspector
        width: parent.width
        controller: workspace.controller
    }
    Connections {
        target: workspace.controller
        function onEditorFocusRequested(): void {
            if (workspace.visible)
                inspector.focusFirstControl();
        }
    }
}
