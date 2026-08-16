import QtQuick
import Shelllist.Ui as Ui
import "BluetoothFlow.js" as BluetoothFlow

Ui.ActionDetailsPane {
    id: pane

    required property BluetoothController controller
    readonly property bool editingText: devicePage.editingName || adapterPage.editing
    readonly property int actionHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property int footerHeight: actionHeight

    chooserController: controller
    emptyText: "Select a Bluetooth device"
    contentAvailable: controller.hasSelection || controller.detailsTab === "adapter"
    headerHeight: Math.max(56, Math.round(64 * uiScale))
    controlHeight: actionHeight
    icon: controller.selectedResult ? controller.selectedResult.icon : "󰒓"
    iconColor: controller.selectedDevice.connected || !controller.hasSelection
        ? Ui.Theme.active : Ui.Theme.mutedText
    iconBorderColor: Ui.Theme.mix(Ui.Theme.strongBorder, Ui.Theme.surface, 0.40)
    title: controller.selectedResult ? controller.selectedResult.title
        : (controller.selectedAdapter.alias || controller.selectedAdapter.name || "Bluetooth adapter")
    subtitle: controller.hasSelection ? BluetoothFlow.deviceState(controller.selectedDevice)
        : "Adapter and management settings"
    subtitleColor: controller.selectedDevice.connected || !controller.hasSelection
        ? Ui.Theme.active : Ui.Theme.mutedText
    subtitleWeight: Ui.Theme.fontWeightMedium
    titlePixelSize: Math.round(Ui.Theme.fontSizeDisplay * uiScale)
    actions: controller.hasSelection ? controller.detailActions : []
    secondaryVisible: controller.hasSelection
    onActionTriggered: function (actionId) { controller.triggerDetailAction(actionId); }

    Ui.TabbedDetailsStack {
        anchors.fill: parent
        footerHeight: pane.footerHeight
        sectionSpacing: pane.sectionSpacing
        selectedValue: pane.controller.detailsTab
        tabs: pane.controller.hasSelection ? [
            { value: "device", icon: "󰋜", label: "Device" },
            { value: "information", icon: "󰋼", label: "Information" },
            { value: "adapter", icon: "󰒓", label: "Bluetooth" }
        ] : [
            { value: "adapter", icon: "󰒓", label: "Bluetooth" }
        ]
        onSelected: function (value) { pane.controller.detailsTab = value; }

        Item {
            width: parent.width / pane.uiScale
            height: parent.height / pane.uiScale
            scale: pane.uiScale
            transformOrigin: Item.TopLeft

            BluetoothDevicePage {
                id: devicePage
                anchors.fill: parent
                visible: pane.controller.hasSelection && pane.controller.detailsTab === "device"
                controller: pane.controller
            }
            BluetoothInformationPage {
                anchors.fill: parent
                visible: pane.controller.hasSelection && pane.controller.detailsTab === "information"
                controller: pane.controller
            }
            BluetoothAdapterPage {
                id: adapterPage
                anchors.fill: parent
                visible: pane.controller.detailsTab === "adapter"
                controller: pane.controller
            }
        }
    }
}
