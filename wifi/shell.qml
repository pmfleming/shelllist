pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "."

ShellRoot {
    id: root

    WifiPromptController {
        id: promptController
    }

    WifiController {
        id: wifiController
        prompt: promptController
        onWindowPlacementRequested: windowHost.requestWindowPlacement()
        onCloseWindowRequested: windowHost.closeRequested()
    }

    WifiWindowHost {
        id: windowHost
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

    Component.onCompleted: wifiController.startup(windowHost.floatingMode, windowHost.shelllistWorkspaceId())
}
