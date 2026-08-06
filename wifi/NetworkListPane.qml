pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui
import "WifiIcons.js" as WifiIcons
import "WifiPresentation.js" as Presentation

ChooserListPane {
    id: pane

    required property WifiController controller
    required property real uiScale
    chooserController: controller
    densityScale: uiScale
    resultModel: controller.powered ? controller.filteredResultsModel : null
    emptyText: controller.powered ? "No Wi-Fi networks"
        : (!controller.radios.wireless_available ? "No Wi-Fi adapter"
        : (!controller.radios.wireless_hardware_enabled ? "Wi-Fi is hardware blocked" : "Wi-Fi is off"))
    placeholder: "Search networks…"
    signalIcon: true
    powered: controller.powered
    refreshing: controller.scanInFlight
    busy: controller.actionInFlight
    powerEnabled: !controller.actionInFlight && !controller.promptActive
    refreshEnabled: controller.powered && !controller.actionInFlight
    iconActionEnabled: !controller.screenshotInFlight && !controller.actionInFlight && !controller.promptActive
    searchActionIcon: "󰐲"
    searchActionToolTip: "Scan a Wi-Fi QR code"
    searchActionEnabled: !controller.actionInFlight
    focusOnCompleted: true
    filterText: controller.filterText
    status: controller.status
    listInset: Math.round(12 * uiScale)
    toolbarHeight: Math.round(Theme.controlHeight * uiScale)
    toolbarComponent: Component {
        WifiRadioToolbar { controller: pane.controller }
    }
    onIconClicked: controller.screenshotRequested()
    onSearchActionRequested: controller.launchQrScanner()
    rowDelegate: Component {
        NetworkListRow {
            id: networkRow
            listPane: pane
            active: !!networkRow.result.state.active
            name: networkRow.result.title
            connecting: pane.controller.connection.isConnecting(networkRow.result.payload)
            progressTick: pane.controller.connection.progressTick
            captivePortal: networkRow.active
                && Presentation.connectivityRequiresSignIn(Presentation.activeConnectivity(pane.controller))
            networkTypeIcon: WifiIcons.forNetwork(networkRow.network, networkRow.captivePortal)
        }
    }
}
