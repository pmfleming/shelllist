pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BluetoothFlow.js" as BluetoothFlow

Ui.ActionDetailsPane {
    id: pane

    required property BluetoothController controller
    // Loader.item is dynamically resolved to the selected detail component.
    // qmllint disable missing-property
    readonly property bool editingText: (deviceLoader.item ? !!deviceLoader.item["editingName"] : false) || (adapterLoader.item ? !!adapterLoader.item["editing"] : false)
    // qmllint enable missing-property
    readonly property int actionHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property int footerHeight: actionHeight
    readonly property bool deviceContext: controller.hasSelection && controller.detailsTab !== "adapter"

    chooserController: controller
    emptyText: "Select a Bluetooth device"
    contentAvailable: controller.hasSelection || controller.detailsTab === "adapter"
    headerHeight: Math.max(56, Math.round(64 * uiScale))
    controlHeight: actionHeight
    icon: deviceContext ? controller.selectedResult.icon : "󰒓"
    iconColor: !deviceContext || controller.selectedDevice.connected ? Ui.Theme.active : Ui.Theme.mutedText
    iconBorderColor: Ui.Theme.mix(Ui.Theme.strongBorder, Ui.Theme.surface, 0.40)
    title: deviceContext ? controller.selectedResult.title : qsTr("Bluetooth")
    subtitle: deviceContext ? BluetoothFlow.deviceState(controller.selectedDevice) : "Computer-wide Bluetooth settings"
    subtitleColor: !deviceContext || controller.selectedDevice.connected ? Ui.Theme.active : Ui.Theme.mutedText
    subtitleWeight: Ui.Theme.fontWeightMedium
    titlePixelSize: Math.round(Ui.Theme.fontSizeDisplay * uiScale)
    actions: deviceContext ? controller.detailActions : []
    secondaryVisible: deviceContext
    onActionTriggered: function (actionId) {
        controller.triggerDetailAction(actionId);
    }

    Ui.TabbedDetailsStack {
        anchors.fill: parent
        objectName: "bluetoothDetailsTabs"
        footerHeight: pane.deviceContext ? pane.footerHeight : 0
        sectionSpacing: pane.deviceContext ? pane.sectionSpacing : 0
        selectedValue: pane.controller.detailsTab
        tabs: pane.deviceContext ? [
            {
                value: "device",
                icon: "󰋜",
                label: "Device"
            },
            {
                value: "information",
                icon: "󰋼",
                label: "Information"
            }
        ] : []
        onSelected: function (value) {
            pane.controller.detailsTab = value;
        }

        Item {
            width: parent.width / pane.uiScale
            height: parent.height / pane.uiScale
            scale: pane.uiScale
            transformOrigin: Item.TopLeft

            Loader {
                id: deviceLoader
                anchors.fill: parent
                active: pane.controller.hasSelection && pane.controller.detailsTab === "device"
                asynchronous: true
                sourceComponent: Component {
                    BluetoothDevicePage {
                        controller: pane.controller
                    }
                }
            }
            Loader {
                anchors.fill: parent
                active: pane.controller.hasSelection && pane.controller.detailsTab === "information"
                asynchronous: true
                sourceComponent: Component {
                    BluetoothInformationPage {
                        controller: pane.controller
                    }
                }
            }
            Loader {
                id: adapterLoader
                anchors.fill: parent
                active: pane.controller.detailsTab === "adapter"
                asynchronous: true
                sourceComponent: Component {
                    BluetoothAdapterPage {
                        controller: pane.controller
                    }
                }
            }
        }
    }
}
