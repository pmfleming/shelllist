pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Shelllist.Ui as Ui
import "BluetoothNoiseControl.js" as NoiseControl

// The hero remains in the page layout. Only this modal menu overlays its bounds;
// its image delegates use the shared ActionMenu traversal and focus restoration.
Ui.ActionMenu {
    id: tray

    required property BluetoothController controller
    readonly property var noiseControl: (controller.selectedDevice.fast_pair || {}).noise_control || ({})
    readonly property string deviceKey: controller.noiseControlDeviceKey
    readonly property bool contextAvailable: controller.canChooseNoiseControl
        && controller.detailsOpen && controller.detailsTab === "device"
        && deviceKey === controller.selectedDevice.key
    readonly property real tileWidth: Math.max(Ui.Theme.formHeight * 2,
        availableWidth / Math.max(1, actions.length))

    objectName: "noiseControlTray"
    listObjectName: "noiseControlChoices"
    accessibleName: qsTr("Noise control")
    width: parent.width
    height: parent.height
    orientation: ListView.Horizontal
    padding: Ui.Theme.spacingSm
    topPadding: padding + Ui.Theme.formActionSize
    dim: false
    visible: controller.noiseControlOpen && contextAvailable
    actions: NoiseControl.availableModes(noiseControl).map(mode => Object.assign({}, mode, {
        deviceKey: tray.deviceKey
    }))
    initialIndex: actions.findIndex(mode => mode.value === noiseControl.active_mode)
    onAboutToHide: {
        if (!contextAvailable || !controller.uiActive || controller.uiSuspending)
            returnFocus = null;
    }
    onClosed: controller.noiseControlOpen = false
    onTriggered: function (action) {
        controller.setNoiseControl(action.deviceKey, action.value);
    }

    background: Rectangle {
        radius: Ui.Theme.cardRadius
        color: Ui.Theme.surfaceRaised
        border.color: Ui.Theme.border
        Ui.ThemeText {
            anchors.left: parent.left
            anchors.leftMargin: tray.padding + Ui.Theme.spacingXs
            anchors.right: closeButton.left
            anchors.verticalCenter: closeButton.verticalCenter
            text: qsTr("Noise control")
            font.pixelSize: Ui.Theme.groupHeadingSize
            font.weight: Ui.Theme.groupHeadingWeight
        }
        Ui.FlatIconButton {
            id: closeButton
            objectName: "closeNoiseControlTray"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Ui.Theme.spacingXs
            width: Ui.Theme.formActionSize
            height: width
            icon: "close"
            label: qsTr("Close noise control")
            activeFocusOnTab: false
            onClicked: tray.close()
        }
    }

    actionDelegate: Component {
        Controls.ItemDelegate {
            id: option
            required property int index
            required property var modelData
            readonly property bool current: tray.noiseControl.active_mode === modelData.value
            objectName: "noiseControlMode:" + modelData.value
            width: tray.tileWidth
            height: tray.availableHeight
            padding: Ui.Theme.spacingXs
            enabled: modelData.enabled
            highlighted: tray.currentIndex === index
            focusPolicy: Qt.NoFocus
            Accessible.role: Accessible.MenuItem
            Accessible.name: modelData.label + (current ? qsTr(". Active") : "")
                + (!enabled ? qsTr(". Not currently settable") : "")
            Accessible.checkable: true
            Accessible.checked: current
            Accessible.focused: tray.listFocused && highlighted
            Accessible.onPressAction: tray.activate(index)
            onClicked: tray.activate(index)

            background: Rectangle {
                anchors.fill: parent
                anchors.margins: Ui.Theme.spacingXs
                radius: Ui.Theme.controlRadius
                color: option.current ? Ui.Theme.selected
                    : option.hovered ? Ui.Theme.hover : "transparent"
                border.color: option.highlighted ? Ui.Theme.accent : "transparent"
                border.width: option.highlighted ? 2 : 0
            }
            contentItem: Column {
                spacing: Ui.Theme.spacingXs
                Image {
                    // Same crop as the existing hero artwork; no new assets.
                    width: Math.min(parent.width, Math.max(0, option.availableHeight
                        - modeLabel.implicitHeight - stateLabel.implicitHeight - parent.spacing * 2))
                    height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: option.modelData.image
                    sourceSize.width: 256
                    sourceSize.height: 256
                    sourceClipRect: Qt.rect(45.5, 40.5, 165, 165.5)
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    opacity: option.enabled ? 1 : Ui.Theme.disabledOpacity
                    Accessible.ignored: true
                }
                Ui.ThemeText {
                    id: modeLabel
                    width: parent.width
                    text: option.modelData.label
                    font.pixelSize: Ui.Theme.metadataSize
                    font.weight: Ui.Theme.fontWeightDemiBold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    Accessible.ignored: true
                }
                Ui.ThemeText {
                    id: stateLabel
                    width: parent.width
                    text: option.current ? qsTr("✓ Active") : !option.enabled ? qsTr("Not settable") : " "
                    color: option.current ? Ui.Theme.active : Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.metadataSize
                    horizontalAlignment: Text.AlignHCenter
                    Accessible.ignored: true
                }
            }
        }
    }
}
