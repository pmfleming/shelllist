pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

ShellRoot {
    ClipboardController { id: controller }

    ClipboardWindowHost {
        id: windowHost
        content: contentComponent
        surfaceWindowWidth: controller.surfaceWindowWidth
        currentWindowWidth: controller.currentWindowWidth
        onUiActivated: function (workspaceId) { controller.activateUi(workspaceId); }
        onUiDeactivated: controller.deactivateUi()
        onFocusSearchRequested: controller.focusSearchRequested()
    }

    Component {
        id: contentComponent
        ClipboardContent { controller: controller; windowHost: windowHost }
    }
}
