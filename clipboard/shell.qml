pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

ShellRoot {
    ClipboardController { id: controller }

    Ui.PopupWindowHost {
        id: windowHost
        modeEnvironment: "SHELLLIST_CLIPBOARD_MODE"
        ipcTarget: "clipboard"
        shortcutName: "clipboard"
        shortcutDescription: "Toggle the Shelllist clipboard history"
        windowTitle: "Shelllist Clipboard"
        layerNamespace: "shelllist-clipboard"
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
