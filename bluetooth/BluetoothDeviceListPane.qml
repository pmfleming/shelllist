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
    emptyText: controller.powered ? "No Bluetooth devices" : "Bluetooth is off"
    placeholder: "Search devices…"
    icon: "󰂯"
    powered: controller.powered
    refreshing: controller.refreshInFlight
    busy: controller.actionInFlight
    powerEnabled: !controller.actionInFlight
    refreshEnabled: controller.powered && !controller.actionInFlight
    filterText: controller.filterText
    status: controller.status
    listInset: Math.round(12 * uiScale)
    onRefreshRequested: controller.toggleScan()

    rowDelegate: Component {
        BluetoothDeviceListRow { listPane: pane }
    }
}
