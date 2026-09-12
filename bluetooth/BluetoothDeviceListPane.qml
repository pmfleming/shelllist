pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BluetoothGlyphs.js" as BluetoothGlyphs

Ui.ChooserListPane {
    id: pane

    required property BluetoothController controller
    chooserController: controller
    resultModel: controller.filteredResultsModel
    emptyText: controller.radio.hard_blocked ? "Bluetooth is hardware-disabled" : (controller.radio.soft_blocked ? "Bluetooth is blocked" : (!controller.radio.available || Number(controller.radio.adapter_count || 0) === 0 ? "No Bluetooth adapters" : (!controller.radio.powered ? "Bluetooth is off" : (controller.searchAllDevices ? "No Bluetooth devices found" : "No devices in My Devices"))))
    emptyIcon: controller.radio.hard_blocked || controller.radio.soft_blocked || (controller.radio.available && Number(controller.radio.adapter_count || 0) > 0 && !controller.radio.powered) ? BluetoothGlyphs.glyphs.blocked : ""
    placeholder: controller.searchAllDevices ? "Search All Devices" : "Search My Devices"
    icon: "󰂯"
    powered: controller.powered
    refreshing: controller.refreshInFlight
    busy: controller.anyActionInFlight
    powerEnabled: !controller.globalRequestInFlight && !controller.radio.hard_blocked
    refreshEnabled: controller.powered && !controller.globalRequestInFlight
    iconActionEnabled: !controller.screenshotInFlight && !controller.actionInFlight && !controller.modalPromptOpen
    searchActionIcon: controller.searchAllDevices ? "󰐷" : "󰒓"
    searchActionToolTip: controller.searchAllDevices ? "All Devices" : "My Devices"
    searchActionEnabled: !controller.globalRequestInFlight && !controller.modalPromptOpen
    filterText: controller.filterText
    status: controller.status
    listInset: Math.round(12 * densityScale)
    refreshHandler: function () {
        controller.refreshList();
    }
    onIconClicked: controller.screenshotRequested()
    onSearchActionRequested: controller.toggleSearchScope()

    listOptionsComponent: Component {
        BluetoothListOptions {
            controller: pane.controller
        }
    }

    rowDelegate: Component {
        BluetoothDeviceListRow {
            listPane: pane
        }
    }
}
