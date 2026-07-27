pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui
import "."

ShellRoot {
    WifiPromptController { id: promptController }
    WifiController { id: wifiController; prompt: promptController }

    Ui.ChooserWindowHost {
        id: windowHost
        controller: wifiController
        applicationId: "wifi"
        displayName: "Wi-Fi"
        content: wifiContentComponent
    }

    Connections {
        target: wifiController
        function onScreenshotRequested() {
            const width = Math.round(wifiController.currentWindowWidth);
            const x = Math.round(windowHost.targetWindowX()
                + (wifiController.surfaceWindowWidth - width) / 2);
            wifiController.captureScreenshot(x, windowHost.targetWindowY(), width, windowHost.currentWindowHeight);
        }
    }

    Component {
        id: wifiContentComponent
        WifiContent { controller: wifiController }
    }
}
