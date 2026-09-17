import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property alias editingName: settings.editingName
    readonly property string selectedTab: controller.detailsTab

    onSelectedTabChanged: {
        if (page.editingName)
            page.forceActiveFocus();
        page.cancelFlick();
        page.contentY = 0;
    }

    Item {
        visible: page.selectedTab === "device"
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

    BluetoothDeviceAudio {
        controller: page.controller
        visible: page.selectedTab === "device" && audioDevice
    }

    Ui.DetailColumnCard {
        height: implicitHeight
        visible: page.selectedTab === "settings"
        title: qsTr("Device settings")
        BluetoothDeviceActions {
            id: settings
            Layout.fillWidth: true
            controller: page.controller
        }
    }

    Ui.DetailColumnCard {
        objectName: "devicePolicy"
        height: implicitHeight
        visible: page.selectedTab === "settings"
        title: qsTr("Connection and pairing")
        BluetoothDevicePolicy {
            Layout.fillWidth: true
            controller: page.controller
        }
    }
}
