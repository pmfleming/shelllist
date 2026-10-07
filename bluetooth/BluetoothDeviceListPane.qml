pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BluetoothGlyphs.js" as BluetoothGlyphs

Ui.ChooserListPane {
    id: pane

    required property BluetoothController controller
    chooserController: controller
    resultModel: controller.filteredResultsModel
    readonly property bool radioDisabled: controller.radio.hard_blocked || controller.radio.soft_blocked || (controller.radio.available && Number(controller.radio.adapter_count || 0) > 0 && !controller.radio.powered)
    emptyState: controller.listError ? "unavailable" : radioDisabled ? "disabled" : controller.backendAvailable && (!controller.radio.available || Number(controller.radio.adapter_count || 0) === 0) ? "empty" : controller.refreshInFlight || controller.backendLoading ? "loading" : !controller.backendAvailable ? "unavailable" : controller.filterText.trim() && controller.allDevices.length > 0 ? "filtered" : "empty"
    emptyIcon: radioDisabled ? BluetoothGlyphs.glyphs.blocked : "bluetooth"
    emptyText: controller.listError || (controller.radio.hard_blocked ? qsTr("Bluetooth is hardware-disabled") : controller.radio.soft_blocked ? qsTr("Bluetooth is blocked") : radioDisabled ? qsTr("Bluetooth is off") : emptyState === "loading" ? qsTr("Looking for Bluetooth devices…") : !controller.backendAvailable ? qsTr("Bluetooth service unavailable") : !controller.radio.available || Number(controller.radio.adapter_count || 0) === 0 ? qsTr("No Bluetooth adapters") : emptyState === "filtered" ? qsTr("No matching devices") : controller.searchAllDevices ? qsTr("No Bluetooth devices found") : qsTr("No devices in My Devices"))
    placeholder: controller.searchAllDevices ? "Search All Devices" : "Search My Devices"
    icon: "󰂯"
    powered: controller.powered
    refreshing: controller.refreshInFlight
    busy: controller.anyActionInFlight
    powerEnabled: !controller.globalRequestInFlight && !controller.radio.hard_blocked
    refreshEnabled: controller.powered && !controller.globalRequestInFlight
    searchActionIcon: "󰒓"
    searchActionToolTip: qsTr("Bluetooth settings")
    searchActionEnabled: !controller.modalPromptOpen
    filterText: controller.filterText
    status: controller.status
    function requestRefresh(): void {
        controller.refreshList();
    }
    onSearchActionRequested: if (searchActionEnabled) {
        controller.toggleBluetoothSettings();
        if (controller.detailsOpen)
            controller.focusDetailsRequested();
    }

    rowDelegate: Component {
        BluetoothDeviceListRow {
            listPane: pane
        }
    }
}
