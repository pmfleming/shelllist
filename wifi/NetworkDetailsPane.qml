import QtQuick
import QtQuick.Layouts
import "Wifi.js" as Wifi

Rectangle {
    id: pane

    required property var controller
    readonly property var ap: controller.detailAp

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 12
    color: "#0f172a"
    border.color: "#1f2a3a"

    Item {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 0
        anchors.bottomMargin: 18

        Column {
            visible: pane.controller.hasSelection
            anchors.fill: parent
            spacing: 14

            RowLayout {
                width: parent.width
                height: 44
                spacing: 16

                Text {
                    Layout.preferredWidth: 54
                    Layout.alignment: Qt.AlignVCenter
                    text: "󰤨"
                    color: "#dbeafe"
                    font.pixelSize: 32
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 5

                    Text {
                        width: parent.width
                        text: Wifi.networkName(pane.ap)
                        color: "#f8fafc"
                        font.pixelSize: 22
                        font.bold: true
                        elide: Text.ElideRight
                    }

                }
            }

            RowLayout {
                width: parent.width
                height: 46
                spacing: 8

                ActionButton {
                    Layout.preferredWidth: 112
                    label: pane.controller.isActive(pane.ap) ? "Disconnect" : "Connect"
                    backgroundColor: pane.controller.isActive(pane.ap) ? "#1e3a5f" : "#1d4ed8"
                    borderColor: "#3b82f6"
                    labelColor: "#dbeafe"
                    enabled: pane.controller.canUsePrimaryAction()
                    onClicked: pane.controller.isActive(pane.ap) ? pane.controller.disconnectSelected() : pane.controller.connectSelected()
                }

                ActionButton {
                    Layout.preferredWidth: 90
                    label: "Forget"
                    enabled: pane.controller.canEditProfile()
                    onClicked: pane.controller.forgetSelected()
                }

                ActionButton {
                    Layout.preferredWidth: 90
                    label: "Sign in"
                    onClicked: pane.controller.openPortal()
                }

                ActionButton {
                    Layout.preferredWidth: 90
                    label: "Share"
                    enabled: pane.controller.canShareSelected()
                    onClicked: pane.controller.shareSelected()
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            DetailCard {
                height: 250
                title: "Connection"

                DetailGrid {
                    DetailField {
                        label: "Signal strength"
                        value: (pane.ap.strength || 0) + "%"
                        valueColor: "#60a5fa"
                        valueBold: true
                    }
                    DetailField {
                        label: "IP address"
                        value: Wifi.activeIp4Value(pane.controller, "address")
                    }
                    DetailField {
                        label: "Frequency"
                        value: Wifi.frequencyLabel(pane.ap)
                    }
                    DetailField {
                        label: "Gateway"
                        value: Wifi.activeIp4Value(pane.controller, "gateway")
                    }
                    DetailField {
                        label: "Security"
                        value: Wifi.securityLabel(pane.ap.security)
                    }
                    DetailField {
                        label: "Subnet"
                        value: Wifi.activeDetailValue(pane.controller, Wifi.subnetLabel(Wifi.detailIp4(pane.controller)))
                    }
                    DetailField {
                        label: "Network usage"
                        value: Wifi.activeDetailValue(pane.controller, Wifi.networkUsageLabel(Wifi.detailConnectionStatus(pane.controller)))
                    }
                    DetailField {
                        label: "DNS"
                        value: Wifi.activeDetailValue(pane.controller, Wifi.dnsLabel(Wifi.detailIp4(pane.controller)))
                        valueWidth: 220
                    }
                }
            }

            DetailCard {
                height: 145
                title: "Network details"

                DetailGrid {
                    DetailField {
                        label: "Type"
                        value: Wifi.wifiType(pane.ap)
                    }
                    DetailField {
                        label: Wifi.hasDirectionalBitrates(pane.controller) ? "Transmit link speed" : "Link speed"
                        value: Wifi.activeDetailValue(pane.controller, Wifi.hasDirectionalBitrates(pane.controller) ? Wifi.txBitrateLabel(pane.controller) : Wifi.bitrateLabel(pane.controller))
                    }
                    DetailField {
                        label: "MAC address"
                        value: Wifi.macLabel(pane.controller) !== "—" ? Wifi.macLabel(pane.controller) : (pane.ap.bssid || "—")
                    }
                    DetailField {
                        label: "Receive link speed"
                        value: Wifi.activeDetailValue(pane.controller, Wifi.rxBitrateLabel(pane.controller))
                    }
                }
            }

            DetailCard {
                height: 208
                title: "Profile settings"

                Column {
                    anchors.fill: parent
                    spacing: 8

                    ProfileToggleRow {
                        title: "Auto-connect"
                        subtitle: pane.controller.profileFor(pane.ap) ? "Connect automatically when this network is in range" : "Connect once before autoconnect is available"
                        checked: pane.controller.autoconnectEnabled()
                        interactive: pane.controller.canEditProfile()
                        onClicked: pane.controller.toggleAutoconnectSelected()
                    }

                    ProfileToggleRow {
                        title: "Use randomised MAC"
                        checked: pane.controller.randomizedMacEnabled()
                        interactive: pane.controller.canEditProfile()
                        onClicked: pane.controller.setMacRandomizedSelected(!pane.controller.randomizedMacEnabled())
                    }

                    ProfileToggleRow {
                        title: "Use device MAC"
                        checked: !pane.controller.randomizedMacEnabled()
                        interactive: pane.controller.canEditProfile()
                        onClicked: pane.controller.setMacRandomizedSelected(false)
                    }

                    ProfileToggleRow {
                        title: "Send device name"
                        subtitle: "Share this device's name with the network"
                        checked: pane.controller.sendHostnameEnabled()
                        interactive: pane.controller.canEditProfile()
                        onClicked: pane.controller.toggleSendHostnameSelected()
                    }
                }
            }

            RowLayout {
                width: parent.width
                height: 20
                Text {
                    text: pane.controller.isActive(pane.ap) && pane.controller.activeStatus && pane.controller.activeStatus.active_since_ms ? "Connected" : ""
                    color: "#64748b"
                    font.pixelSize: 12
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: Wifi.lastSeenLabel(pane.ap)
                    color: "#64748b"
                    font.pixelSize: 12
                }
            }
        }

        Text {
            visible: !pane.controller.hasSelection
            anchors.centerIn: parent
            text: "Select a network"
            color: "#94a3b8"
            font.pixelSize: 22
        }
    }
}
