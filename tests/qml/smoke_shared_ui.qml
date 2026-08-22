import Quickshell
import QtQuick
import Shelllist.Ui as Ui

ShellRoot {
    Ui.ChooserController {
        id: controller
        uiActive: true
    }

    Item {
        width: 900
        height: 700

        Ui.ProviderChooserSurface {
            anchors.fill: parent
            chooserController: controller
            surfaceName: "Smoke test"
            listComponent: Component { Item {} }
            detailsComponent: Component { Item {} }
        }
    }

    Timer {
        interval: 50
        running: true
        onTriggered: Qt.quit()
    }
}
