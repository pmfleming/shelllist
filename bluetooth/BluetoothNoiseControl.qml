pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BluetoothNoiseControl.js" as NoiseControl

Item {
    id: control

    required property BluetoothController controller
    property int referenceArtworkSize: 86
    readonly property var fastPair: controller.selectedDevice.fast_pair || ({})
    readonly property var noiseControl: fastPair.noise_control || ({})
    readonly property var activeMode: NoiseControl.activeMode(noiseControl)
    readonly property bool advertised: NoiseControl.isAdvertised(noiseControl)
    readonly property int iconExtent: Math.max(92, Math.round(referenceArtworkSize * 1.15))

    visible: advertised
    implicitHeight: advertised ? iconExtent + Ui.Theme.spacingXs + modeLabel.implicitHeight : 0

    Accessible.role: Accessible.StaticText
    Accessible.name: activeMode.label

    Image {
        id: icon
        objectName: "noiseControlIcon"
        anchors.right: parent.right
        width: control.iconExtent
        height: control.iconExtent
        source: control.activeMode.image
        sourceSize.width: 256
        sourceSize.height: 256
        // Remove the shared transparent canvas padding so alignment follows the artwork.
        sourceClipRect: Qt.rect(45.5, 40.5, 165, 165.5)
        fillMode: Image.Stretch
        smooth: true
        mipmap: true
        Accessible.ignored: true
    }

    TextMetrics {
        id: cancellationMetrics
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeSmall
        font.weight: Ui.Theme.fontWeightDemiBold
        text: qsTr("cancellation")
    }

    Ui.ThemeText {
        id: modeLabel
        objectName: "noiseControlLabel"
        anchors.top: icon.bottom
        anchors.topMargin: Ui.Theme.spacingXs
        anchors.horizontalCenter: icon.horizontalCenter
        width: icon.width
        text: control.activeMode.value === "noise-cancelling" ? qsTr("Noise\ncancellation") : control.activeMode.label
        // Use the same size for every mode, with no label overflow at the window edge.
        font.pixelSize: Math.min(Ui.Theme.fontSizeSmall, Math.floor(Ui.Theme.fontSizeSmall * width / Math.max(1, cancellationMetrics.advanceWidth)))
        font.weight: Ui.Theme.fontWeightDemiBold
        horizontalAlignment: Text.AlignHCenter
        Accessible.ignored: true
    }
}
