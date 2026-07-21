import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BluetoothFlow.js" as BluetoothFlow

Rectangle {
    id: pane

    required property BluetoothController controller
    required property real uiScale
    readonly property bool editingText: devicePage.editingName || adapterPage.editing
    readonly property int sectionSpacing: Math.max(Ui.Theme.spacingSm, Math.round(Ui.Theme.spacingMd * uiScale))
    readonly property int headerHeight: Math.max(56, Math.round(64 * uiScale))
    readonly property int actionHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property int footerHeight: actionHeight

    radius: 0
    color: "transparent"
    border.color: "transparent"
    clip: true

    Item {
        anchors.fill: parent
        anchors.leftMargin: Math.round(Ui.Theme.spacingLg * pane.uiScale)
        anchors.rightMargin: Math.round(Ui.Theme.spacingLg * pane.uiScale)
        anchors.bottomMargin: 2

        Column {
            visible: pane.controller.hasSelection
            anchors.fill: parent
            spacing: pane.sectionSpacing

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

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Ui.Theme.spacingXs

                    Text {
                        width: parent.width
                        text: pane.controller.selectedResult ? pane.controller.selectedResult.title : "Bluetooth device"
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Math.round(Ui.Theme.fontSizeDisplay * pane.uiScale)
                        font.weight: Ui.Theme.fontWeightBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: pane.controller.hasSelection ? BluetoothFlow.deviceState(pane.controller.selectedDevice) : ""
                        color: pane.controller.selectedDevice.connected ? Ui.Theme.active : Ui.Theme.mutedText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Math.max(Ui.Theme.fontSizeCaption, Math.round(Ui.Theme.fontSizeSmall * pane.uiScale))
                        font.weight: Ui.Theme.fontWeightMedium
                        elide: Text.ElideRight
                    }
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
                id: viewport
                width: parent.width
                height: Math.max(0, parent.height - pane.headerHeight - 2 * pane.actionHeight - 3 * parent.spacing)
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

            Item {
                width: parent.width
                height: pane.footerHeight

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Ui.Theme.border
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Ui.DetailsTab {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "󰋜"
                        label: "Device Details"
                        selected: pane.controller.detailsTab === "device"
                        onClicked: pane.controller.detailsTab = "device"
                    }
                    Ui.DetailsTab {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "󰓃"
                        label: "Audio & Transfer"
                        selected: pane.controller.detailsTab === "audio"
                        onClicked: pane.controller.detailsTab = "audio"
                    }
                    Ui.DetailsTab {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "󰒓"
                        label: "Adapter"
                        selected: pane.controller.detailsTab === "adapter"
                        onClicked: pane.controller.detailsTab = "adapter"
                    }
                }
            }
        }

        Ui.CenteredMessage {
            visible: !pane.controller.hasSelection
            text: "Select a Bluetooth device"
            font.pixelSize: Ui.Theme.fontSizeTitle
        }
    }
}
