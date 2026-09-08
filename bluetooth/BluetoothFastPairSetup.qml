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
    checked: !!features.account_key_available
    // Provisioning stores a credential; there is no disable operation in bt-api.
    interactive: !controller.actionInFlight && !checked
        && (canPairWithMetadata || !!caps.can_provision_fast_pair)
    onClicked: if (interactive) controller.provisionFastPair()
}
