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
    dim: false
    clip: true
    enter: Transition {
        NumberAnimation {
            target: tray
            property: "horizontalOffset"
            from: tray.width
            to: 0
            duration: Ui.Theme.noAnimations ? 0 : Ui.Theme.animationNormal
            easing.type: Easing.OutCubic
        }
    }
    exit: Transition {
        NumberAnimation {
            target: tray
            property: "horizontalOffset"
            to: tray.width
            duration: Ui.Theme.noAnimations ? 0 : Ui.Theme.animationNormal
            easing.type: Easing.InCubic
        }
    }
    visible: controller.noiseControlOpen && contextAvailable
    actions: NoiseControl.availableModes(noiseControl).map(mode => Object.assign({}, mode, {
        deviceKey: tray.deviceKey
    }))
    initialIndex: actions.findIndex(mode => mode.value === noiseControl.active_mode)
    onAboutToHide: {
        if (!contextAvailable || !controller.uiActive || controller.uiSuspending)
            returnFocus = null;
    }
    onVisibleChanged: controller.noiseControlPresented = visible
    Component.onDestruction: if (controller) controller.noiseControlPresented = false
    onClosed: controller.noiseControlOpen = false
    onTriggered: function (action) {
        controller.setNoiseControl(action.deviceKey, action.value);
    }

    background: Rectangle {
        color: Ui.Theme.window
        transform: Translate { x: tray.horizontalOffset }
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

            background: Item {}
            contentItem: Column {
                spacing: Ui.Theme.spacingXs
                Image {
                    // Same crop as the existing hero artwork; no new assets.
                    objectName: "noiseControlArtwork:" + option.modelData.value
                    width: Math.min(parent.width, Math.max(0, option.availableHeight
                        - modeLabel.implicitHeight - parent.spacing))
                    height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: option.modelData.image
                    sourceSize.width: 256
                    sourceSize.height: 256
                    sourceClipRect: Qt.rect(45.5, 40.5, 165, 165.5)
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    // Brightness describes device state, never the unsubmitted
                    // keyboard candidate. Focus has its own label underline.
                    opacity: option.current ? 1 : option.enabled ? Ui.Theme.disabledOpacity
                        : Ui.Theme.disabledOpacity * Ui.Theme.disabledOpacity
                    Accessible.ignored: true
                }
                Ui.ThemeText {
                    id: modeLabel
                    width: parent.width
                    text: option.modelData.label
                    font.pixelSize: Ui.Theme.metadataSize
                    font.weight: Ui.Theme.fontWeightDemiBold
                    font.underline: option.highlighted && tray.listFocused
                    color: option.highlighted && tray.listFocused ? Ui.Theme.accent : Ui.Theme.text
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    Accessible.ignored: true
                }
            }
        }
    }
}
