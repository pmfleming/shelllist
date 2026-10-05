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
            listComponent: Component {
                Item {}
            }
            detailsComponent: Component {
                Item {}
            }
        }

        Ui.ScrollableListView {
            visible: false
            width: 120
            height: 80
            model: 4
            delegate: Item {
                required property int index
                width: 120
                height: 24
            }
        }
    }

    // Native Quickshell screen objects, not JSON stand-ins, feed window delegates.
    Variants {
        model: Quickshell.screens
        QtObject {
            required property ShellScreen modelData
            readonly property ShellScreen targetScreen: modelData
            Component.onCompleted: {
                if (!targetScreen || targetScreen !== modelData)
                    throw new Error("Screen delegate lost its typed target");
            }
        }
    }

    Timer {
        interval: 50
        running: true
        onTriggered: Qt.quit()
    }
}
