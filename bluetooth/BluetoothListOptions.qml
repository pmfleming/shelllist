import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: options

    required property BluetoothController controller
    objectName: "bluetoothListOptions"
    title: qsTr("List options")

    Ui.FieldLabel {
        text: qsTr("Device list")
    }
    Ui.SegmentedControl {
        objectName: "bluetoothSearchScope"
        Layout.fillWidth: true
        Layout.preferredHeight: Ui.Theme.compactControlHeight
        options: [
            {value: "mine", label: "My Devices"},
            {value: "all", label: "All Devices"}
        ]
        value: options.controller.searchScope
        interactive: !options.controller.globalRequestInFlight
        onSelected: function (value) {
            options.controller.setSearchScope(value);
        }
    }
    Ui.ToggleRow {
        objectName: "showBlockedDevices"
        Layout.fillWidth: true
        title: qsTr("Show blocked devices")
        subtitle: qsTr("Include devices so they can be unblocked")
        checked: !!options.controller.management.show_blocked_devices
        interactive: !options.controller.globalRequestInFlight
        onClicked: options.controller.updateManagement({show_blocked_devices: !checked})
    }
    Ui.ToggleRow {
        objectName: "showRecentDevices"
        Layout.fillWidth: true
        title: qsTr("Show recently found devices")
        subtitle: qsTr("Include cached devices in All Devices")
        checked: !!options.controller.management.show_recent_devices
        interactive: !options.controller.globalRequestInFlight
        onClicked: options.controller.updateManagement({show_recent_devices: !checked})
    }
}
