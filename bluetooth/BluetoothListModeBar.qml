import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

RowLayout {
    id: bar
    required property BluetoothController controller
    spacing: Ui.Theme.spacingSm

    Ui.SegmentedControl {
        Layout.fillWidth: true
        Layout.preferredHeight: Ui.Theme.compactControlHeight
        options: [
            { value: "managed", label: "My Devices" },
            { value: "discovery", label: "Add Device" }
        ]
        value: bar.controller.viewMode
        interactive: !bar.controller.globalRequestInFlight
        onSelected: function (value) { bar.controller.setViewMode(value); }
    }

    Ui.ActionButton {
        visible: bar.controller.viewMode === "managed"
        Layout.preferredWidth: visible ? 94 : 0
        Layout.preferredHeight: Ui.Theme.compactControlHeight
        label: bar.controller.management.show_blocked_devices ? "Blocked: On" : "Blocked"
        tone: bar.controller.management.show_blocked_devices ? "active" : "normal"
        enabled: !bar.controller.globalRequestInFlight
        onClicked: bar.controller.updateManagement({
            show_blocked_devices: !bar.controller.management.show_blocked_devices
        })
    }

    Ui.ActionButton {
        Layout.preferredWidth: 42
        Layout.preferredHeight: Ui.Theme.compactControlHeight
        icon: "󰒓"
        accessibleName: "Bluetooth adapter and management settings"
        enabled: !bar.controller.globalRequestInFlight
        onClicked: bar.controller.openAdapterSettings()
    }
}
