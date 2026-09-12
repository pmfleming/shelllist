import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DisclosureSection {
    id: options

    required property BluetoothController controller
    objectName: "bluetoothListOptions"
    title: qsTr("Device list options")

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
