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
        : (controller.discoveryMode ? "No nearby devices found" : "No managed Bluetooth devices"))))
    placeholder: controller.discoveryMode ? "Search nearby devices…" : "Search my devices…"
    icon: "󰂯"
    powered: controller.powered
    refreshing: controller.refreshInFlight
    busy: controller.anyActionInFlight
    powerEnabled: !controller.globalRequestInFlight && !controller.radio.hard_blocked
    refreshEnabled: controller.powered && !controller.globalRequestInFlight
    iconActionEnabled: !controller.screenshotInFlight && !controller.actionInFlight && !controller.modalPromptOpen
    filterText: controller.filterText
    status: controller.status
    listInset: Math.round(12 * uiScale)
    refreshHandler: function () { controller.refreshList(); }
    toolbarComponent: Component { BluetoothListModeBar { controller: pane.controller } }
    onIconClicked: controller.screenshotRequested()

    rowDelegate: Component {
        BluetoothDeviceListRow { listPane: pane }
    }
}
