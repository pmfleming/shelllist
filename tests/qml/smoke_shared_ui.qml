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

        Ui.ScrollableListView {
            visible: false
            width: 120
            height: 80
            model: 4
            delegate: Item { required property int index; width: 120; height: 24 }
        }
    }

    Timer {
        interval: 50
        running: true
        onTriggered: Qt.quit()
    }
}
