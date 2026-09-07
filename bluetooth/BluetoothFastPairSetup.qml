pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: setup
    required property BluetoothController controller
    readonly property var device: controller.selectedDevice
    readonly property var features: device.fast_pair || ({})
    readonly property var caps: device.capabilities || ({})
    readonly property bool canPairWithMetadata: !device.paired && !!features.trusted_model_name && !!caps.can_pair
    spacing: Ui.Theme.spacingSm

    Text {
        Layout.fillWidth: true
        text: "Model ID: " + (setup.features.model_id || "not reported")
            + (setup.features.trusted_model_name ? " · local metadata: " + setup.features.trusted_model_name : "")
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
    Text {
        Layout.fillWidth: true
        text: setup.features.account_key_available
            ? (setup.features.authenticated_controls ? "Account key stored; authenticated controls are available." : "Account key stored; waiting for a secure Message Stream.")
            : (setup.features.provisioning_reason || "The recent pairing window is open. Enable controls now.")
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
    Ui.ActionButton {
        Layout.fillWidth: true
        Layout.preferredHeight: Ui.Theme.compactControlHeight
        label: setup.canPairWithMetadata ? "Pair and enable Fast Pair controls" : "Enable Fast Pair controls"
        enabled: !setup.controller.actionInFlight && (setup.canPairWithMetadata || !!setup.caps.can_provision_fast_pair)
        onClicked: setup.controller.provisionFastPair()
    }
    Text {
        Layout.fillWidth: true
        text: "Uses traditional Bluetooth pairing followed by Google's retroactive account-key procedure. Trusted model keys must be installed locally; advertisements are not trusted keys. Google account sync and automatic Audio Switch are not supported."
        wrapMode: Text.WordWrap
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
}
