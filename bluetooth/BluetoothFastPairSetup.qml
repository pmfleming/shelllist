pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Ui.ToggleRow {
    id: setup
    required property BluetoothController controller
    readonly property var device: controller.selectedDevice
    readonly property var features: device.fast_pair || ({})
    readonly property var caps: device.capabilities || ({})
    readonly property bool canPairWithMetadata: !device.paired && !!features.trusted_model_name && !!caps.can_pair

    title: "Fast Pair controls"
    showSubtitle: false
    checked: !!features.account_key_available && (device.policy || {}).fast_pair_controls_enabled !== false
    interactive: !controller.actionInFlight
        && (!!features.account_key_available || canPairWithMetadata || !!caps.can_provision_fast_pair)
    onClicked: if (interactive) controller.setFastPairControlsEnabled(!checked)
}
