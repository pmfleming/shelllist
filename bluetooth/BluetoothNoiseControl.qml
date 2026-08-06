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
    readonly property var modes: NoiseControl.modes()
    readonly property bool advertised: NoiseControl.isAdvertised(noiseControl)
    readonly property bool canSetNoiseControl: !!(controller.selectedDevice.capabilities
        && controller.selectedDevice.capabilities.can_set_noise_control)
    readonly property bool interactive: !controller.actionInFlight && canSetNoiseControl
    // The source artwork has generous transparent margins. This produces visible
    // marks around one quarter of the rendered device artwork.
    readonly property int iconExtent: Math.max(28, Math.round(referenceArtworkSize * 0.4))

    visible: advertised
    implicitHeight: advertised ? iconExtent + 2 * Ui.Theme.spacingSm : 0
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

    Row {
        id: modeRow

        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingXs
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
                readonly property bool activatable: control.interactive && modeAvailable
                readonly property bool selected: control.noiseControl.active_mode === modelData.value

                width: (modeRow.width - modeRow.spacing * 3) / 4
                height: modeRow.height
                radius: Ui.Theme.controlRadius
                color: selected ? Ui.Theme.selected
                    : (pointer.pressed ? Ui.Theme.pressed
                    : (activatable && hover.hovered ? Ui.Theme.hover : "transparent"))
                border.width: selected || activeFocus ? 1 : 0
                border.color: activeFocus ? Ui.Theme.strongBorder : Ui.Theme.accent
                activeFocusOnTab: activatable

                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.label
                Accessible.description: modeAvailable ? "" : "Unavailable"
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

                    anchors.centerIn: parent
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

                HoverHandler { id: hover }

                Controls.ToolTip.visible: hover.hovered
                Controls.ToolTip.text: modeButton.modelData.label
                    + (modeButton.modeAvailable ? "" : " — Unavailable")
                Controls.ToolTip.delay: 450

                Ui.ControlPointerArea {
                    id: pointer
                    focusTarget: modeButton
                    enabled: modeButton.activatable
                    onClicked: control.choose(modeButton.index)
                }
            }
        }
    }
}
