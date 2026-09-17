pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section
    required property BluetoothController controller
    readonly property var policy: controller.selectedDevice.policy || ({})
    readonly property var settings: [
        {id: "reconnect_on_resume", label: "Reconnect after wake"},
        {id: "trust_after_pair", label: "Trust after pairing"},
        {id: "power_on_connect", label: "Power adapter when connecting"},
        {id: "wait_for_services", label: "Wait for services"}
    ]
    readonly property var actions: settings.map(function (setting) {
        return {
            id: setting.id,
            label: setting.label,
            state: {checked: section.policy[setting.id] !== false},
            enabled: !section.controller.actionInFlight
        };
    })

    spacing: Ui.Theme.spacingSm
    Ui.FieldLabel { text: qsTr("Override defaults") }
    Ui.ThemeText {
        Layout.fillWidth: true
        text: qsTr("Values shown are effective for this device. Changes override defaults. Reset restores all device defaults, including audio preferences.")
        wrapMode: Text.WordWrap
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
    Ui.ActionToggleList {
        Layout.fillWidth: true
        actions: section.actions
        // These controls are disabled only while busy, not because they are unsupported.
        showDisabledReason: false
        onTriggered: function (field) {
            const values = ({});
            values[field] = section.policy[field] === false;
            section.controller.updateDevicePolicy(values);
        }
    }
}
