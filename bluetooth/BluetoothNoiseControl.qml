pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Effects
import Shelllist.Ui as Ui
import "BluetoothNoiseControl.js" as NoiseControl

Rectangle {
    id: control

    required property BluetoothController controller
    property int referenceArtworkSize: 86
    readonly property var fastPair: controller.selectedDevice.fast_pair || ({})
    readonly property var noiseControl: fastPair.noise_control || ({})
    readonly property var displayModes: NoiseControl.availableModes(noiseControl)
    readonly property bool advertised: NoiseControl.isAdvertised(noiseControl)
    readonly property int iconExtent: Math.max(28, Math.round(referenceArtworkSize * 0.4))

    visible: advertised
    implicitHeight: advertised ? iconExtent + 2 * Ui.Theme.spacingSm : 0
    radius: Ui.Theme.controlRadius
    color: Ui.Theme.withAlpha(Ui.Theme.input, 0.72)
    border.width: 1
    border.color: Ui.Theme.border

    Accessible.role: Accessible.StaticText
    Accessible.name: "Noise control: " + NoiseControl.activeLabel(noiseControl)
    Accessible.description: "Read-only headphone status"

    Row {
        id: modeRow

        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingXs
        spacing: Ui.Theme.spacingXs

        Repeater {
            id: modeRepeater

            model: control.displayModes

            delegate: Rectangle {
                id: modeIndicator

                required property var modelData
                readonly property bool selected: NoiseControl.isActive(control.noiseControl, modelData.value)

                width: (modeRow.width - modeRow.spacing * Math.max(0, modeRepeater.count - 1))
                    / Math.max(1, modeRepeater.count)
                height: modeRow.height
                radius: Ui.Theme.controlRadius
                color: selected ? Ui.Theme.selected : "transparent"
                border.width: selected ? 1 : 0
                border.color: Ui.Theme.accent

                Accessible.role: Accessible.StaticText
                Accessible.name: modelData.label + (selected ? " — active" : " — inactive")
                Accessible.description: "Read-only noise-control status"

                Image {
                    anchors.centerIn: parent
                    width: control.iconExtent
                    height: control.iconExtent
                    source: modeIndicator.modelData.image
                    sourceSize.width: 128
                    sourceSize.height: 128
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    opacity: modeIndicator.selected ? 1.0 : 0.38
                    layer.enabled: !modeIndicator.selected
                    layer.effect: MultiEffect { saturation: -1.0 }
                }

                HoverHandler { id: hover }

                Controls.ToolTip.visible: hover.hovered
                Controls.ToolTip.text: modeIndicator.modelData.label
                    + (modeIndicator.selected ? " — Active" : " — Inactive")
                    + " · Read-only"
                Controls.ToolTip.delay: 450
            }
        }
    }
}
