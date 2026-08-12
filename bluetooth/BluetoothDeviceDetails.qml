import QtQuick
import Shelllist.Ui as Ui
import "BluetoothFlow.js" as BluetoothFlow

Ui.DetailsPane {
    id: pane

    required property BluetoothController controller
    required property real uiScale
    readonly property bool editingText: devicePage.editingName || adapterPage.editing
    readonly property int headerHeight: Math.max(56, Math.round(64 * uiScale))
    readonly property int actionHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property int secondaryActionsHeight: controller.hasSelection ? actionHeight : 0
    readonly property int footerHeight: actionHeight

    chooserController: controller
    densityScale: uiScale
    emptyText: "Select a Bluetooth device"
    contentAvailable: controller.hasSelection || controller.detailsTab === "adapter"

    Ui.DetailsHeader {
        width: parent.width
        height: pane.headerHeight
        uiScale: pane.uiScale
        icon: pane.controller.selectedResult ? pane.controller.selectedResult.icon : "󰒓"
        iconColor: pane.controller.selectedDevice.connected || !pane.controller.hasSelection ? Ui.Theme.active : Ui.Theme.mutedText
        iconBorderColor: Ui.Theme.mix(Ui.Theme.strongBorder, Ui.Theme.surface, 0.40)
        title: pane.controller.selectedResult ? pane.controller.selectedResult.title
            : (pane.controller.selectedAdapter.alias || pane.controller.selectedAdapter.name || "Bluetooth adapter")
        subtitle: pane.controller.hasSelection ? BluetoothFlow.deviceState(pane.controller.selectedDevice) : "Adapter and management settings"
        subtitleColor: pane.controller.selectedDevice.connected || !pane.controller.hasSelection ? Ui.Theme.active : Ui.Theme.mutedText
        subtitleWeight: Ui.Theme.fontWeightMedium
        titlePixelSize: Math.round(Ui.Theme.fontSizeDisplay * pane.uiScale)
        actions: pane.controller.hasSelection ? pane.controller.detailActions : []
        controlHeight: pane.actionHeight
        onActionTriggered: function (actionId) { pane.controller.triggerDetailAction(actionId); }
    }

    Ui.ActionToolbar {
        visible: pane.controller.hasSelection
        width: parent.width
        height: pane.secondaryActionsHeight
        actions: pane.controller.detailActions
        group: "toolbar"
        alignRight: true
        controlHeight: pane.actionHeight
        onTriggered: function (actionId) { pane.controller.triggerDetailAction(actionId); }
    }

    Item {
        width: parent.width
        height: Math.max(0, parent.height - pane.headerHeight - pane.secondaryActionsHeight
            - pane.footerHeight - 3 * pane.sectionSpacing)
        clip: true

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

    Ui.DetailsTabBar {
        width: parent.width
        height: pane.footerHeight
        selectedValue: pane.controller.detailsTab
        tabs: pane.controller.hasSelection ? [
            { value: "device", icon: "󰋜", label: "Device" },
            { value: "information", icon: "󰋼", label: "Information" },
            { value: "adapter", icon: "󰒓", label: "Bluetooth" }
        ] : [
            { value: "adapter", icon: "󰒓", label: "Bluetooth" }
        ]
        onSelected: function (value) { pane.controller.detailsTab = value; }
    }
}
