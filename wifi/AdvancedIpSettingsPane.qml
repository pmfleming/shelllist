pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."
import "networkinput" as NetworkInput
import Shelllist.Ui

AdvancedSettingsFlickable {
    id: hardwareFlick

    required property AdvancedSettingsPage settings
    viewMemory: settings.controller.viewMemory
    memoryTab: "hardware"

    contentHeight: hardwareCards.implicitHeight

    Column {
        id: hardwareCards

        width: hardwareFlick.width
        spacing: hardwareFlick.settings.sectionSpacing

        DetailColumnCard {
            objectName: "wifiIpSettingsCard"
            title: qsTr("IP & DNS")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                AdvancedSegmentedRow {
                    Layout.fillWidth: true
                    objectName: "wifiIpFamily"
                    label: "Address family"
                    value: hardwareFlick.settings.ipFamily
                    options: [
                        {
                            value: "ipv4",
                            label: "IPv4"
                        },
                        {
                            value: "ipv6",
                            label: "IPv6"
                        }
                    ]
                    onSelected: function (value) {
                        hardwareFlick.settings.ipFamily = value;
                    }
                }

                ToggleRow {
                    Layout.fillWidth: true
                    objectName: "wifiIpEnabled"
                    title: hardwareFlick.settings.ipFamily === "ipv4" ? "Enable IPv4" : "Enable IPv6"
                    showSubtitle: false
                    checked: hardwareFlick.settings.currentFamilyEnabled
                    onClicked: hardwareFlick.settings.setMethod(hardwareFlick.settings.currentFamilyEnabled ? "disabled" : "auto")
                }

                ToggleRow {
                    Layout.fillWidth: true
                    objectName: "wifiIpAutomatic"
                    title: qsTr("Automatic addressing")
                    showSubtitle: false
                    checked: hardwareFlick.settings.currentMethod === "auto"
                    interactive: hardwareFlick.settings.currentFamilyEnabled
                    onClicked: hardwareFlick.settings.setMethod(hardwareFlick.settings.currentMethod === "auto" ? "manual" : "auto")
                }

                ToggleRow {
                    Layout.fillWidth: true
                    objectName: "wifiDnsAutomatic"
                    title: qsTr("Automatic DNS")
                    showSubtitle: false
                    checked: hardwareFlick.settings.currentAutoDns
                    interactive: hardwareFlick.settings.currentFamilyEnabled
                    onClicked: hardwareFlick.settings.setAutoDns(!hardwareFlick.settings.currentAutoDns)
                }

                ThemeText {
                    visible: hardwareFlick.settings.currentMethod === "manual"
                    text: qsTr("* Required for manual addressing")
                    font.pixelSize: Theme.formSupportSize
                    color: Theme.mutedText
                }
                GridLayout {
                    id: addressGroup
                    Layout.fillWidth: true
                    columns: width >= 640 ? 2 : 1
                    columnSpacing: Theme.spacingMd
                    rowSpacing: Theme.spacingSm
                    FormField {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: hardwareFlick.settings.ipFamily === "ipv6" ? "IPv6" : "IPv4"
                        icon: "lan"
                        accessibleName: hardwareFlick.settings.ipFamily === "ipv6" ? qsTr("IPv6 address") : qsTr("IPv4 address")
                        requiredInput: hardwareFlick.settings.currentMethod === "manual"
                        readOnlyReason: !hardwareFlick.settings.currentFamilyEnabled ? qsTr("IP family disabled") : ipAddress.readOnly ? qsTr("Assigned automatically") : ""
                        copyAvailable: ipAddress.readOnly && ipAddress.enabled && ipAddress.text.length > 0
                        onCopyRequested: hardwareFlick.settings.controller.copyText(ipAddress.text, qsTr("IP address copied"))
                        NetworkInput.IpAddressField {
                            id: ipAddress
                            Layout.fillWidth: true
                            enabled: hardwareFlick.settings.currentFamilyEnabled
                            family: hardwareFlick.settings.ipFamily
                            allowEmpty: hardwareFlick.settings.currentMethod !== "manual"
                            readOnly: hardwareFlick.settings.currentMethod !== "manual"
                            objectName: "wifiIpAddress"
                            text: hardwareFlick.settings.displayedAddress
                            onEdited: function (value) {
                                hardwareFlick.settings.currentIp.address = value;
                            }
                            onEditingFinished: hardwareFlick.settings.queueHardwareSave()
                        }
                    }
                    FormField {
                        Layout.fillWidth: addressGroup.columns === 1
                        Layout.preferredWidth: 168
                        Layout.alignment: Qt.AlignTop
                        // The slash is the visible identity; the full name and
                        // range remain in accessibility and the named Help command.
                        label: ""
                        icon: ""
                        requiredInput: hardwareFlick.settings.currentMethod === "manual"
                        accessibleName: hardwareFlick.settings.ipFamily === "ipv6" ? qsTr("IPv6 prefix length") : qsTr("IPv4 prefix length")
                        NetworkInput.PrefixLengthField {
                            Layout.fillWidth: true
                            enabled: hardwareFlick.settings.currentFamilyEnabled
                            family: hardwareFlick.settings.ipFamily
                            allowEmpty: hardwareFlick.settings.currentMethod !== "manual"
                            readOnly: hardwareFlick.settings.currentMethod !== "manual"
                            objectName: "wifiIpPrefix"
                            text: hardwareFlick.settings.displayedPrefix
                            onEdited: function (value) {
                                hardwareFlick.settings.currentIp.prefix = value;
                            }
                            onEditingFinished: hardwareFlick.settings.queueHardwareSave()
                        }
                    }
                }
                FormField {
                    Layout.fillWidth: true
                    label: qsTr("Gateway")
                    icon: "route"
                    accessibleName: qsTr("Gateway (optional)")
                    readOnlyReason: !hardwareFlick.settings.currentFamilyEnabled ? qsTr("IP family disabled") : gateway.readOnly ? qsTr("Assigned automatically") : ""
                    copyAvailable: gateway.readOnly && gateway.enabled && gateway.text.length > 0
                    onCopyRequested: hardwareFlick.settings.controller.copyText(gateway.text, qsTr("Gateway copied"))
                    NetworkInput.IpAddressField {
                        id: gateway
                        Layout.fillWidth: true
                        enabled: hardwareFlick.settings.currentFamilyEnabled
                        placeholder: qsTr("Optional")
                        family: hardwareFlick.settings.ipFamily
                        readOnly: hardwareFlick.settings.currentMethod !== "manual"
                        objectName: "wifiIpGateway"
                        text: hardwareFlick.settings.displayedGateway
                        onEdited: function (value) {
                            hardwareFlick.settings.currentIp.gateway = value;
                        }
                        onEditingFinished: hardwareFlick.settings.queueHardwareSave()
                    }
                }
                FormField {
                    Layout.fillWidth: true
                    label: qsTr("DNS")
                    icon: "dns"
                    accessibleName: qsTr("DNS servers")
                    readOnlyReason: !hardwareFlick.settings.currentFamilyEnabled ? qsTr("IP family disabled") : dnsServers.readOnly ? qsTr("Assigned automatically") : ""
                    copyAvailable: dnsServers.readOnly && dnsServers.enabled && dnsServers.text.length > 0
                    onCopyRequested: hardwareFlick.settings.controller.copyText(dnsServers.text, qsTr("DNS servers copied"))
                    NetworkInput.AddressListField {
                        id: dnsServers
                        Layout.fillWidth: true
                        enabled: hardwareFlick.settings.currentFamilyEnabled
                        family: hardwareFlick.settings.ipFamily
                        readOnly: !hardwareFlick.settings.currentFamilyEnabled || hardwareFlick.settings.currentAutoDns
                        objectName: "wifiDnsServers"
                        text: hardwareFlick.settings.displayedDns
                        onEdited: function (value) {
                            hardwareFlick.settings.currentIp.dns = value;
                        }
                        onEditFinished: function (saved) {
                            if (saved)
                                hardwareFlick.settings.queueHardwareSave();
                        }
                    }
                }
                FormField {
                    Layout.fillWidth: true
                    label: qsTr("Domains")
                    icon: "language"
                    accessibleName: qsTr("DNS search domains (optional)")
                    supportingText: qsTr("Comma or whitespace separated")
                    TextField {
                        Layout.fillWidth: true
                        enabled: hardwareFlick.settings.currentFamilyEnabled
                        readOnly: !hardwareFlick.settings.currentFamilyEnabled
                        objectName: "wifiDnsSearch"
                        text: hardwareFlick.settings.currentIp.search
                        placeholder: qsTr("Optional")
                        onEdited: function (value) {
                            hardwareFlick.settings.currentIp.search = value;
                        }
                        onEditingFinished: hardwareFlick.settings.queueHardwareSave()
                    }
                }
            }
        }
    }
}
