pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui
import "WifiIcons.js" as WifiIcons
import "WifiPresentation.js" as Presentation

ChooserListPane {
    id: pane

    required property WifiController controller
    chooserController: controller
    resultModel: controller.powered ? controller.filteredResultsModel : null
    readonly property bool radioDisabled: controller.radios.wireless_available && !controller.powered
    emptyIcon: radioDisabled ? "wifi_off" : "wifi"
    emptyState: controller.networksError ? "unavailable" : radioDisabled ? "disabled" : !controller.radios.wireless_available ? "empty" : controller.scanInFlight ? "loading" : !controller.networksLoaded ? "unavailable" : controller.filterText.trim() && controller.visibleNetworks.length > 0 ? "filtered" : "empty"
    emptyText: controller.networksError || (!controller.radios.wireless_available ? qsTr("No Wi-Fi adapter") : !controller.radios.wireless_hardware_enabled ? qsTr("Wi-Fi is hardware blocked") : !controller.powered ? qsTr("Wi-Fi is off") : emptyState === "loading" ? qsTr("Scanning for networks…") : emptyState === "unavailable" ? qsTr("Wi-Fi network information unavailable") : emptyState === "filtered" ? qsTr("No matching networks") : qsTr("No Wi-Fi networks found"))
    placeholder: "Search networks…"
    signalIcon: true
    powered: controller.powered
    refreshing: controller.scanInFlight
    busy: controller.actionInFlight
    powerEnabled: !controller.actionInFlight && !controller.promptActive
    refreshEnabled: controller.powered && !controller.promptActive
    searchActionIcon: "󰐲"
    searchActionToolTip: "Scan a Wi-Fi QR code"
    searchActionEnabled: !controller.promptActive && !controller.qr.scannerRunning
    filterText: controller.filterText
    status: controller.status
    onSearchActionRequested: controller.launchQrScanner()
    rowDelegate: Component {
        NetworkListRow {
            id: networkRow
            listPane: pane
            active: !!networkRow.result.state.active
            name: networkRow.result.title
            connecting: pane.controller.connection.isConnecting(networkRow.result.payload)
            progressTick: pane.controller.connection.progressTick
            captivePortal: networkRow.active && Presentation.connectivityRequiresSignIn(Presentation.activeConnectivity(pane.controller))
            networkTypeIcon: WifiIcons.forNetwork(networkRow.network, networkRow.captivePortal)
        }
    }
}
