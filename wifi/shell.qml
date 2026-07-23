pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui
import "."

ShellRoot {
    id: root

    WifiPromptController {
        id: promptController
    }

    WifiController {
        id: wifiController
        prompt: promptController
        onCloseWindowRequested: windowHost.closeRequested()
    }

    Ui.PopupWindowHost {
        id: windowHost
        modeEnvironment: "SHELLLIST_WIFI_MODE"
        ipcTarget: "wifi"
        shortcutName: "wifi"
        shortcutDescription: "Toggle the Shelllist Wi-Fi chooser"
        windowTitle: "Shelllist Wi-Fi"
        layerNamespace: "shelllist-wifi"
        content: wifiContentComponent
        surfaceWindowWidth: wifiController.surfaceWindowWidth
        currentWindowWidth: wifiController.currentWindowWidth
        onUiActivated: function (workspaceId) { wifiController.activateUi(workspaceId); }
        onUiDeactivated: wifiController.deactivateUi()
        onFocusSearchRequested: wifiController.navigation.focusSearch()
    }

    Component {
        id: wifiContentComponent

        WifiContent {
            controller: wifiController
        }
    }

}
