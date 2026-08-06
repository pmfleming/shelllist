pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Shelllist.Ui as Ui
import "BluetoothNoiseControl.js" as NoiseControl

Rectangle {
    id: control

    required property BluetoothController controller
    property int referenceArtworkSize: 86
    readonly property var fastPair: controller.selectedDevice.fast_pair || ({})
    readonly property var noiseControl: fastPair.noise_control || ({})
    readonly property var modes: NoiseControl.modes()
    readonly property bool advertised: NoiseControl.isAdvertised(noiseControl)
    readonly property bool canSetNoiseControl: !!(controller.selectedDevice.capabilities
        && controller.selectedDevice.capabilities.can_set_noise_control)
    readonly property bool interactive: !controller.actionInFlight && canSetNoiseControl
    // The source artwork has generous transparent margins. This produces visible
    // marks around one quarter of the rendered device artwork.
    readonly property int iconExtent: Math.max(28, Math.round(referenceArtworkSize * 0.4))

    visible: advertised
    implicitHeight: advertised ? 94 : 0
    radius: Ui.Theme.controlRadius
    color: Ui.Theme.withAlpha(Ui.Theme.input, 0.72)
    border.width: 1
    border.color: Ui.Theme.border

    function choose(index) {
        if (!interactive || index < 0 || index >= modes.length)
            return;
        const mode = modes[index].value;
        if (NoiseControl.isSettable(noiseControl, mode))
            controller.setNoiseControl(mode);
    }

    function focusAdjacent(index, delta) {
        const nextIndex = NoiseControl.adjacentSettableIndex(noiseControl, index, delta);
        const nextButton = nextIndex >= 0 ? modeRepeater.itemAt(nextIndex) : null;
        if (nextButton)
            nextButton.forceActiveFocus();
    }

    Text {
        id: heading

        x: Ui.Theme.spacingMd
        y: Ui.Theme.spacingSm
        width: parent.width - 2 * Ui.Theme.spacingMd
        text: "Noise control"
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightMedium
        horizontalAlignment: Text.AlignHCenter
    }

    Row {
        id: modeRow

        x: Ui.Theme.spacingXs
        y: heading.y + heading.height + Ui.Theme.spacingXs
        width: parent.width - 2 * Ui.Theme.spacingXs
        height: parent.height - y - Ui.Theme.spacingXs
        spacing: Ui.Theme.spacingXs

        Repeater {
            id: modeRepeater

            model: control.modes

            delegate: Rectangle {
                id: modeButton

                required property int index
                required property var modelData
                readonly property bool modeAvailable: control.canSetNoiseControl
                    && NoiseControl.isSettable(control.noiseControl, modelData.value)
                readonly property bool selected: control.noiseControl.active_mode === modelData.value

                width: (modeRow.width - modeRow.spacing * 3) / 4
                height: modeRow.height
                radius: Ui.Theme.controlRadius
                color: selected ? Ui.Theme.selected
                    : (pointer.pressed ? Ui.Theme.pressed
                    : (pointer.containsMouse ? Ui.Theme.hover : "transparent"))
                border.width: selected || activeFocus ? 1 : 0
                border.color: activeFocus ? Ui.Theme.strongBorder : Ui.Theme.accent
                enabled: control.interactive && modeAvailable
                activeFocusOnTab: enabled

                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.label
                Accessible.checked: selected
                Accessible.onPressAction: control.choose(index)

                Keys.onLeftPressed: function (event) {
                    control.focusAdjacent(modeButton.index, -1);
                    event.accepted = true;
                }
                Keys.onRightPressed: function (event) {
                    control.focusAdjacent(modeButton.index, 1);
                    event.accepted = true;
                }
                Keys.onReturnPressed: function (event) { control.choose(modeButton.index); event.accepted = true; }
                Keys.onEnterPressed: function (event) { control.choose(modeButton.index); event.accepted = true; }
                Keys.onSpacePressed: function (event) { control.choose(modeButton.index); event.accepted = true; }

                Image {
                    id: modeImage

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    width: control.iconExtent
                    height: control.iconExtent
                    source: modeButton.modelData.image
                    sourceSize.width: 128
                    sourceSize.height: 128
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    opacity: modeButton.modeAvailable ? 1.0 : 0.38
                    layer.enabled: !modeButton.modeAvailable
                    layer.effect: MultiEffect { saturation: -1.0 }
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: modeImage.bottom
                    anchors.bottom: parent.bottom
                    leftPadding: 2
                    rightPadding: 2
                    text: modeButton.modelData.label
                    color: modeButton.modeAvailable ? Ui.Theme.text : Ui.Theme.disabledText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                    font.weight: modeButton.selected ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                Ui.ControlPointerArea {
                    id: pointer
                    focusTarget: modeButton
                    enabled: modeButton.enabled
                    onClicked: control.choose(modeButton.index)
                }
            }
        }
    }
}
