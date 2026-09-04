pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BluetoothNoiseControl.js" as NoiseControl

Rectangle {
    id: control

    required property BluetoothController controller
    property int referenceArtworkSize: 86
    readonly property var fastPair: controller.selectedDevice.fast_pair || ({})
    readonly property var noiseControl: fastPair.noise_control || ({})
    readonly property var activeMode: NoiseControl.activeMode(noiseControl)
    readonly property bool advertised: NoiseControl.isAdvertised(noiseControl)
    readonly property int iconExtent: Math.max(92, Math.round(referenceArtworkSize * 1.15))

    visible: advertised
    implicitHeight: advertised ? iconExtent + 2 * Ui.Theme.spacingSm : 0
    color: "transparent"

    Accessible.role: Accessible.StaticText
    Accessible.name: "Sound isolation: " + activeMode.label

    Row {
        anchors.centerIn: parent
        spacing: Ui.Theme.spacingMd

        Image {
            width: control.iconExtent
            height: control.iconExtent
            source: control.activeMode.image
            sourceSize.width: 256
            sourceSize.height: 256
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            Accessible.ignored: true
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Ui.Theme.spacingXs

            Text {
                text: "Sound isolation"
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeSmall
                font.weight: Ui.Theme.fontWeightMedium
                Accessible.ignored: true
            }

            Text {
                text: control.activeMode.label
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeTitle
                font.weight: Ui.Theme.fontWeightDemiBold
                Accessible.ignored: true
            }
        }
    }
}
