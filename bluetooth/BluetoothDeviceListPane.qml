pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Shelllist.Ui as Ui
import "BluetoothGlyphs.js" as BluetoothGlyphs

Ui.ChooserListPane {
    id: pane

    required property BluetoothController controller
    readonly property bool optionsOpen: optionsPopup.visible
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
    iconActionEnabled: !controller.modalPromptOpen
    iconAccessibleName: qsTr("Bluetooth settings and list options")
    searchActionIcon: controller.searchAllDevices ? "󰐷" : "󰒓"
    searchActionToolTip: controller.searchAllDevices ? "All Devices" : "My Devices"
    searchActionEnabled: !controller.globalRequestInFlight && !controller.modalPromptOpen
    filterText: controller.filterText
    status: controller.status
    listInset: Math.round(12 * densityScale)
    refreshHandler: function () {
        controller.refreshList();
    }
    onIconClicked: optionsPopup.visible ? optionsPopup.close() : optionsPopup.open()
    onIconActionEnabledChanged: if (!iconActionEnabled) optionsPopup.close()
    onSearchActionRequested: controller.toggleSearchScope()

    Controls.Popup {
        id: optionsPopup
        objectName: "bluetoothOptionsPopup"
        y: pane.headerHeight + Ui.Theme.spacingSm
        width: pane.width
        padding: Ui.Theme.spacingMd
        focus: true
        modal: true
        dim: false
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        onClosed: pane.focusSearch()
        background: Rectangle {
            color: Ui.Theme.surface
            border.color: Ui.Theme.border
            radius: Ui.Theme.controlRadius
        }
        contentItem: BluetoothListOptions {
            controller: pane.controller
            onSettingsRequested: {
                optionsPopup.close();
                pane.controller.openBluetoothSettings();
            }
        }
    }

    Connections {
        target: pane.controller
        function onUiActiveChanged() {
            if (!pane.controller.uiActive) optionsPopup.close();
        }
    }

    rowDelegate: Component {
        BluetoothDeviceListRow {
            listPane: pane
        }
    }
}
