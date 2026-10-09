import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: options

    required property BluetoothController controller
    objectName: "bluetoothListOptions"
    title: qsTr("List options")

    Ui.FormField {
        Layout.fillWidth: true
        label: qsTr("Device list")
        Ui.SegmentedControl {
            objectName: "bluetoothSearchScope"
            Layout.fillWidth: true
            options: [{value: "mine", label: qsTr("My devices")}, {value: "all", label: qsTr("All devices")}]
            value: options.controller.searchScope
            interactive: !options.controller.globalRequestInFlight
            onSelected: function (value) { options.controller.setSearchScope(value); }
        }
    }
    Ui.ToggleRow {
        objectName: "showBlockedDevices"
        Layout.fillWidth: true
        title: qsTr("Show blocked devices")
        subtitle: qsTr("Include devices so they can be unblocked")
        checked: !!options.controller.management.show_blocked_devices
        interactive: !options.controller.globalRequestInFlight
        onClicked: options.controller.updateManagement({
            show_blocked_devices: !checked
        })
    }
    Ui.ToggleRow {
        objectName: "showRecentDevices"
        Layout.fillWidth: true
        title: qsTr("Show recently found devices")
        subtitle: qsTr("Include cached devices in All devices")
        checked: !!options.controller.management.show_recent_devices
        interactive: !options.controller.globalRequestInFlight
        onClicked: options.controller.updateManagement({
            show_recent_devices: !checked
        })
    }
}
