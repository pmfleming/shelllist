import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property alias editingName: settings.editingName

    Item {
        width: parent.width
        height: noiseControl.visible ? Math.max(batteryStatus.implicitHeight, noiseControl.y + noiseControl.implicitHeight) : batteryStatus.implicitHeight

        BluetoothBatteryStatus {
            id: batteryStatus
            width: parent.width - (noiseControl.visible ? noiseControl.iconExtent + Ui.Theme.spacingMd : 0)
            height: implicitHeight
            device: page.controller.selectedDevice
        }

        BluetoothNoiseControl {
            id: noiseControl
            anchors.right: parent.right
            width: iconExtent
            height: implicitHeight
            y: batteryStatus.percentageBottom - iconExtent
            controller: page.controller
            referenceArtworkSize: batteryStatus.artworkSize
        }
    }

    BluetoothDeviceAudio { controller: page.controller }

    Ui.DetailColumnCard {
        height: implicitHeight
        title: qsTr("Device settings")
        BluetoothDeviceActions {
            id: settings
            Layout.fillWidth: true
            controller: page.controller
        }
    }

    Ui.DetailColumnCard {
        objectName: "deviceOverrides"
        height: implicitHeight
        title: qsTr("Advanced device options")
        BluetoothDevicePolicy {
            Layout.fillWidth: true
            controller: page.controller
        }
    }
}
