pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui
import "."

ShellRoot {
    WifiPromptController { id: promptController }
    WifiController { id: wifiController; prompt: promptController }

    Ui.ChooserWindowHost {
        controller: wifiController
        applicationId: "wifi"
        displayName: "Wi-Fi"
        content: wifiContentComponent
    }


    Component {
        id: wifiContentComponent
        WifiContent { controller: wifiController }
    }
}
