pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane

    required property BluetoothController controller
    required property real uiScale
    chooserController: controller
    densityScale: uiScale
    resultModel: controller.filteredResultsModel
    emptyText: controller.radio.hard_blocked ? "Bluetooth is hardware-disabled"
        : (controller.radio.soft_blocked ? "Bluetooth is blocked"
        : (!controller.radio.available || Number(controller.radio.adapter_count || 0) === 0 ? "No Bluetooth adapters"
        : (!controller.radio.powered ? "Bluetooth is off"
        : (controller.searchAllDevices ? "No Bluetooth devices found" : "No devices in My Devices"))))
    placeholder: controller.searchAllDevices ? "Search All Devices" : "Search My Devices"
    icon: "󰂯"
    powered: controller.powered
    refreshing: controller.refreshInFlight
    busy: controller.anyActionInFlight
    powerEnabled: !controller.globalRequestInFlight && !controller.radio.hard_blocked
    refreshEnabled: controller.powered && !controller.globalRequestInFlight
    iconActionEnabled: !controller.screenshotInFlight && !controller.actionInFlight && !controller.modalPromptOpen
    searchActionIcon: controller.searchAllDevices ? "󰂯" : "󰂱"
    searchActionToolTip: controller.searchAllDevices ? "Search All Devices" : "Search My Devices"
    searchActionEnabled: !controller.globalRequestInFlight && !controller.modalPromptOpen
    filterText: controller.filterText
    status: controller.status
    listInset: Math.round(12 * uiScale)
    refreshHandler: function () { controller.refreshList(); }
    onIconClicked: controller.screenshotRequested()
    onSearchActionRequested: controller.toggleSearchScope()

    rowDelegate: Component {
        BluetoothDeviceListRow { listPane: pane }
    }
}
