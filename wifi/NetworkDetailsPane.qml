import QtQuick
import QtQuick.Layouts
import "Wifi.js" as Wifi
import "."

Rectangle {
    required property var controller
    readonly property var ap: controller.detailAp
    readonly property var connectionRows: [
        { label: "Signal strength", value: (ap.strength || 0) + "%", valueColor: Theme.accent, valueBold: true },
        { label: "IP address", value: Wifi.activeIp4Value(controller, "address") },
        { label: "Frequency", value: Wifi.frequencyLabel(ap) },
        { label: "Gateway", value: Wifi.activeIp4Value(controller, "gateway") },
        { label: "Security", value: Wifi.securityLabel(ap.security) },
        { label: "Subnet", value: Wifi.activeDetailValue(controller, Wifi.subnetLabel(Wifi.detailIp4(controller))) },
        { label: "Network usage", value: Wifi.activeDetailValue(controller, Wifi.networkUsageLabel(Wifi.detailConnectionStatus(controller))) },
        { label: "DNS", value: Wifi.activeDetailValue(controller, Wifi.dnsLabel(Wifi.detailIp4(controller))), valueWidth: 220 }
    ]
    readonly property var networkRows: [
        { label: "Type", value: Wifi.wifiType(ap) },
        { label: Wifi.hasDirectionalBitrates(controller) ? "Transmit link speed" : "Link speed", value: Wifi.activeDetailValue(controller, Wifi.hasDirectionalBitrates(controller) ? Wifi.txBitrateLabel(controller) : Wifi.bitrateLabel(controller)) },
        { label: "MAC address", value: Wifi.macLabel(controller) !== "—" ? Wifi.macLabel(controller) : (ap.bssid || "—") },
        { label: "Receive link speed", value: Wifi.activeDetailValue(controller, Wifi.rxBitrateLabel(controller)) }
    ]

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
        anchors.topMargin: 0
        anchors.bottomMargin: 18

        Column {
            visible: controller.hasSelection
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

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 5

                    Text {
                        width: parent.width
                        text: Wifi.networkName(ap)
                        color: Theme.text
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
                    label: controller.isConnecting(ap) ? "Connecting…" : (controller.isActive(ap) ? "Disconnect" : "Connect")
                    hotkey: controller.isActive(ap) ? "D" : "C"
                    backgroundColor: controller.isActive(ap) ? Theme.danger : Theme.active
                    borderColor: controller.isActive(ap) ? Theme.danger : Theme.active
                    labelColor: controller.isActive(ap) ? Theme.dangerText : Theme.activeText
                    enabled: controller.canUsePrimaryAction()
                    onClicked: controller.isActive(ap) ? controller.disconnectSelected() : controller.connectSelected()
                }

                ActionButton {
                    Layout.preferredWidth: 90
                    label: "Forget"
                    hotkey: "F"
                    enabled: controller.canEditProfile()
                    onClicked: controller.forgetSelected()
                }

                ActionButton {
                    Layout.preferredWidth: 90
                    label: "Sign in"
                    hotkey: "I"
                    onClicked: controller.openPortal()
                }

                ActionButton {
                    Layout.preferredWidth: 90
                    label: "Share"
                    hotkey: "S"
                    enabled: controller.canShareSelected()
                    onClicked: controller.shareSelected()
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            DetailCard {
                height: 250
                title: "Connection"

                DetailGrid { entries: connectionRows }
            }

            DetailCard {
                height: 145
                title: "Network details"

                DetailGrid { entries: networkRows }
            }

            DetailCard {
                height: 174
                title: "Profile settings"

                Column {
                    anchors.fill: parent
                    spacing: 8

                    ProfileToggleRow {
                        title: "Auto-connect"
                        hotkey: "A"
                        subtitle: controller.profileFor(ap) ? "Connect automatically when this network is in range" : "Connect once before autoconnect is available"
                        checked: controller.autoconnectEnabled()
                        interactive: controller.canEditProfile()
                        onClicked: controller.toggleAutoconnectSelected()
                    }

                    ProfileToggleRow {
                        title: "Randomise MAC address"
                        hotkey: "R"
                        subtitle: controller.randomizedMacEnabled() ? "Use a stable private MAC for this network" : "Use this device's hardware MAC for this network"
                        checked: controller.randomizedMacEnabled()
                        interactive: controller.canEditProfile()
                        onClicked: controller.toggleRandomizedMacSelected()
                    }

                    ProfileToggleRow {
                        title: "Send device name"
                        hotkey: "N"
                        subtitle: "Share this device's name with the network"
                        checked: controller.sendHostnameEnabled()
                        interactive: controller.canEditProfile()
                        onClicked: controller.toggleSendHostnameSelected()
                    }
                }
            }

            RowLayout {
                width: parent.width
                height: 20
                Text {
                    text: controller.isActive(ap) && controller.activeStatus && controller.activeStatus.active_since_ms ? "Connected" : ""
                    color: Theme.subtleText
                    font.pixelSize: 12
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: Wifi.lastSeenLabel(ap)
                    color: Theme.subtleText
                    font.pixelSize: 12
                }
            }
        }

        Text {
            visible: !controller.hasSelection
            anchors.centerIn: parent
            text: "Select a network"
            color: Theme.mutedText
            font.pixelSize: 22
        }
    }
}
