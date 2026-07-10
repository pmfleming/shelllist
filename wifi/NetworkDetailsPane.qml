import QtQuick
import QtQuick.Layouts
import "Wifi.js" as Wifi
import "."

Rectangle {
    id: pane

    required property var controller
    readonly property var ap: controller.detailAp

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: Theme.panelRadius
    color: Theme.surface
    border.color: Theme.border
    clip: true

    Item {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.bottomMargin: 18

        Column {
            visible: pane.controller.hasSelection
            anchors.fill: parent
            spacing: 14

            RowLayout {
                width: parent.width
                height: 44
                spacing: 16

                IconTile {
                    Layout.preferredWidth: 54
                    Layout.preferredHeight: 44
                    Layout.alignment: Qt.AlignVCenter
                    icon: "󰤨"
                    iconColor: Theme.accent
                    iconSize: 32
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: Wifi.networkName(pane.ap)
                    color: Theme.text
                    font.pixelSize: 22
                    font.bold: true
                    elide: Text.ElideRight
                }
            }

            NetworkDetailsActions { controller: pane.controller }

            DetailCard {
                height: 250
                title: "Connection"
                DetailGrid { entries: Wifi.connectionDetailRows(pane.controller, pane.ap, Theme.accent) }
            }

            DetailCard {
                height: 145
                title: "Network details"
                DetailGrid { entries: Wifi.networkDetailRows(pane.controller, pane.ap) }
            }

            NetworkProfileSettingsCard { controller: pane.controller }

            RowLayout {
                width: parent.width
                height: 20

                Text {
                    text: Wifi.connectionStateLabel(pane.controller, pane.ap)
                    color: Theme.subtleText
                    font.pixelSize: 12
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Wifi.lastSeenLabel(pane.ap)
                    color: Theme.subtleText
                    font.pixelSize: 12
                }
            }
        }

        Text {
            visible: !pane.controller.hasSelection
            anchors.centerIn: parent
            text: "Select a network"
            color: Theme.mutedText
            font.pixelSize: 22
        }
    }
}
