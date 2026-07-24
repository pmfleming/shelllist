pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui

ChooserListPane {
    id: pane

    required property WifiController controller
    required property real uiScale
    chooserController: controller
    densityScale: uiScale
    resultModel: controller.powered ? controller.filteredResultsModel : null
    emptyText: controller.powered ? "No Wi-Fi networks" : "Wi-Fi is off"
    placeholder: "Search networks…"
    signalIcon: true
    powered: controller.powered
    refreshing: controller.scanInFlight
    busy: controller.actionInFlight
    powerEnabled: !controller.actionInFlight && !controller.prompt.open
    refreshEnabled: controller.powered && !controller.actionInFlight
    focusOnCompleted: true
    filterText: controller.filterText
    status: controller.status
    listInset: Math.round(12 * uiScale)
    onFilterEdited: function (text) {
        controller.filterText = text;
        controller.selectedIndex = 0;
    }
    onSearchKeyPressed: function (event) { controller.navigation.handleSearchKey(event); }
    onListKeyPressed: function (event) { controller.navigation.handleListKey(event); }
    onPowerRequested: controller.setPower()
    onRefreshRequested: controller.refresh()

    rowDelegate: Component {
        NetworkListRow {
            id: networkRow
            listPane: pane
            active: !!networkRow.result.state.active
            name: networkRow.result.title
            connecting: pane.controller.connection.isConnecting(networkRow.result.payload)
            progressTick: pane.controller.connection.progressTick
        }
    }
}
