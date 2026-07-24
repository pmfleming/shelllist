import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BluetoothFlow.js" as BluetoothFlow

Ui.DetailsPane {
    id: pane

    required property BluetoothController controller
    required property real uiScale
    readonly property bool editingText: devicePage.editingName || adapterPage.editing
    readonly property int headerHeight: Math.max(56, Math.round(64 * uiScale))
    readonly property int actionHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property int footerHeight: actionHeight

    chooserController: controller
    densityScale: uiScale
    emptyText: "Select a Bluetooth device"

    RowLayout {
                width: parent.width
                height: pane.headerHeight
                spacing: Ui.Theme.spacingMd

                Ui.IconTile {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 54
                    Layout.alignment: Qt.AlignVCenter
                    icon: pane.controller.selectedResult ? pane.controller.selectedResult.icon : "󰂯"
                    iconColor: pane.controller.selectedDevice.connected ? Ui.Theme.active : Ui.Theme.mutedText
                    iconSize: Math.round(Ui.Theme.iconSizeLarge * pane.uiScale)
                    backgroundColor: Ui.Theme.selected
                    borderColor: Ui.Theme.mix(Ui.Theme.strongBorder, Ui.Theme.surface, 0.40)
                }

                Ui.ResultLabel {
                    title: pane.controller.selectedResult ? pane.controller.selectedResult.title : "Bluetooth device"
                    subtitle: pane.controller.hasSelection ? BluetoothFlow.deviceState(pane.controller.selectedDevice) : ""
                    subtitleColor: pane.controller.selectedDevice.connected ? Ui.Theme.active : Ui.Theme.mutedText
                    titleWeight: Ui.Theme.fontWeightBold
                    subtitleWeight: Ui.Theme.fontWeightMedium
                    titlePixelSize: Math.round(Ui.Theme.fontSizeDisplay * pane.uiScale)
                    subtitlePixelSize: Math.max(Ui.Theme.fontSizeCaption, Math.round(Ui.Theme.fontSizeSmall * pane.uiScale))
                }

                Ui.ActionToolbar {
                    Layout.preferredWidth: 170
                    Layout.preferredHeight: pane.actionHeight
                    actions: pane.controller.detailActions
                    group: "primary"
                    controlHeight: pane.actionHeight
                    onTriggered: function (actionId) { pane.controller.triggerDetailAction(actionId); }
                }
            }

            Ui.ActionToolbar {
                width: parent.width
                height: pane.actionHeight
                actions: pane.controller.detailActions
                group: "toolbar"
                controlHeight: pane.actionHeight
                onTriggered: function (actionId) { pane.controller.triggerDetailAction(actionId); }
            }

            Item {
                width: parent.width
                height: Math.max(0, parent.height - pane.headerHeight - 2 * pane.actionHeight - 3 * pane.sectionSpacing)
                clip: true

                Item {
                    width: parent.width / pane.uiScale
                    height: parent.height / pane.uiScale
                    scale: pane.uiScale
                    transformOrigin: Item.TopLeft

                    BluetoothDevicePage {
                        id: devicePage
                        anchors.fill: parent
                        visible: pane.controller.detailsTab === "device"
                        controller: pane.controller
                    }
                    BluetoothAudioTransferPage {
                        anchors.fill: parent
                        visible: pane.controller.detailsTab === "audio"
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
        tabs: [
            { value: "device", icon: "󰋜", label: "Device Details" },
            { value: "audio", icon: "󰓃", label: "Audio & Transfer" },
            { value: "adapter", icon: "󰒓", label: "Adapter" }
        ]
        onSelected: function (value) { pane.controller.detailsTab = value; }
    }
}
