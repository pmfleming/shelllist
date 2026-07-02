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
        windowHost: windowHost
    }

    WifiWindowHost {
        id: windowHost
        controller: wifiController
        content: wifiContentComponent
    }

    Component {
        id: wifiContentComponent

        WifiContent {
            controller: wifiController
        }
    }

    Component.onCompleted: wifiController.startup()
}
