import QtQuick
import QtQuick.Layouts
import "Wifi.js" as Wifi
import "."

Rectangle {
    id: pane

    required property var controller
    readonly property var ap: controller.detailAp
    readonly property string connectionLabel: Wifi.connectionStateLabel(controller, ap)
    readonly property string lastSeenLabel: Wifi.lastSeenLabel(ap)
    readonly property real uiScale: Math.max(0.82, Math.min(1.12, height / 850))
    readonly property int sectionSpacing: Math.max(8, Math.round(12 * uiScale))
    readonly property int headerHeight: Math.max(56, Math.round(64 * uiScale))
    readonly property int actionsHeight: 44
    readonly property int footerHeight: Math.max(44, Math.round(50 * uiScale))
    readonly property real cardBudget: Math.max(420, contentColumn.height - headerHeight - actionsHeight - footerHeight - 5 * sectionSpacing)
    readonly property real connectionCardHeight: Math.round(cardBudget * 0.44)
    readonly property real networkCardHeight: Math.round(cardBudget * 0.255)
    readonly property real profileCardHeight: Math.max(0, cardBudget - connectionCardHeight - networkCardHeight)

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 0
    color: "transparent"
    border.color: "transparent"
    clip: true

    Item {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 16
        anchors.bottomMargin: 2

        Column {
            id: contentColumn

            visible: pane.controller.hasSelection
            anchors.fill: parent
            spacing: pane.sectionSpacing

            RowLayout {
                width: parent.width
                height: pane.headerHeight
                spacing: 14

                Item {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 54
                    Layout.alignment: Qt.AlignVCenter

                    SignalIcon {
                        anchors.centerIn: parent
                        width: Math.round(48 * pane.uiScale)
                        height: Math.round(40 * pane.uiScale)
                        level: 3
                        iconColor: Theme.accent
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 7

                    Text {
                        width: parent.width
                        text: Wifi.networkName(pane.ap)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(22 * pane.uiScale)
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Row {
                        height: 18
                        spacing: 8

                        Rectangle {
                            visible: pane.controller.isActive(pane.ap)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: width / 2
                            color: Theme.active
                        }

                        Text {
                            visible: pane.connectionLabel.length > 0
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: pane.connectionLabel
                            color: pane.controller.isActive(pane.ap) ? Theme.active : Theme.mutedText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        Text {
                            visible: pane.connectionLabel.length > 0 && pane.lastSeenLabel.length > 0
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: "/"
                            color: Theme.subtleText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            visible: pane.lastSeenLabel.length > 0
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: pane.lastSeenLabel
                            color: Theme.mutedText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: 156
                    Layout.preferredHeight: 44
                    Layout.alignment: Qt.AlignVCenter

                    NetworkDetailsActions {
                        anchors.fill: parent
                        controller: pane.controller
                        primaryOnly: true
                        alignRight: true
                    }
                }
            }

            NetworkDetailsActions {
                controller: pane.controller
                primaryOnly: false
                alignRight: true
                width: parent.width
                height: pane.actionsHeight
            }

            DetailCard {
                height: pane.connectionCardHeight
                title: "Connection"

                DetailGrid {
                    entries: Wifi.connectionDetailRows(pane.controller, pane.ap, Theme.accent).slice(0, 8)
                }
            }

            DetailCard {
                height: pane.networkCardHeight
                title: "Network details"

                DetailGrid {
                    entries: Wifi.networkDetailRows(pane.controller, pane.ap).slice(0, 4)
                }
            }

            NetworkProfileSettingsCard {
                controller: pane.controller
                height: pane.profileCardHeight
            }

            Rectangle {
                width: parent.width
                height: pane.footerHeight
                radius: Theme.cardRadius
                color: Theme.withAlpha(Theme.surfaceRaised, 0.96)
                border.color: Theme.mix(Theme.border, Theme.text, 0.12)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Text {
                        text: "󰐲"
                        color: Theme.mix(Theme.mutedText, Theme.text, 0.22)
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 18
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "More advanced settings"
                        color: Theme.mix(Theme.mutedText, Theme.text, 0.22)
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        text: "󰅂"
                        color: Theme.mix(Theme.mutedText, Theme.text, 0.22)
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 16
                    }
                }
            }
        }

        Text {
            visible: !pane.controller.hasSelection
            anchors.centerIn: parent
            text: "Select a network"
            color: Theme.mutedText
            font.family: Theme.fontFamily
            font.pixelSize: 20
        }
    }
}
