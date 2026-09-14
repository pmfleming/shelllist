import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: options

    required property BluetoothController controller
    property bool expanded: false
    signal settingsRequested()
    objectName: "bluetoothListOptions"
    spacing: Ui.Theme.spacingSm

    ColumnLayout {
        Layout.fillWidth: true
        Ui.ActionButton {
            objectName: "openBluetoothSettings"
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: qsTr("Bluetooth settings")
            onClicked: options.settingsRequested()
        }
        Ui.ActionButton {
            objectName: "disclosureButton"
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: qsTr("List options")
            icon: options.expanded ? "󰅀" : "󰅂"
            accessibleName: options.expanded ? "Collapse device list options" : "Expand device list options"
            onClicked: options.expanded = !options.expanded
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: options.expanded
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
}
