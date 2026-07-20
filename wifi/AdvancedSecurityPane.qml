pragma ComponentBehavior: Bound

import QtQuick
import "."
import Shelllist.Ui

AdvancedSettingsFlickable {
    id: securityFlick

    required property var settings

    contentHeight: securityCards.implicitHeight

    Column {
        id: securityCards

        width: securityFlick.width
        spacing: securityFlick.settings.sectionSpacing

        DetailCard {
            height: 245
            title: "Device"

            DetailGrid {
                entries: [
                    { label: "BSSID", value: securityFlick.settings.ap.bssid || "—" },
                    { label: "Device MAC", value: ((securityFlick.settings.status.wireless || {}).mac_address || "—") },
                    { label: "Profile path", value: securityFlick.settings.profile.path || "—" },
                    { label: "Interface", value: securityFlick.settings.ap.device_iface || securityFlick.settings.status.device_iface || "—" },
                    { label: "Mode", value: securityFlick.settings.ap.mode ? "Wi-Fi " + securityFlick.settings.ap.mode : "Infrastructure" },
                    { label: "Band / frequency", value: (securityFlick.settings.ap.band || "—") + " / " + (securityFlick.settings.ap.frequency || "—") + " MHz" },
                    { label: "Channel", value: securityFlick.settings.ap.channel === undefined ? "—" : String(securityFlick.settings.ap.channel) },
                    { label: "Maximum bitrate", value: securityFlick.settings.ap.max_bitrate_mbps ? securityFlick.settings.ap.max_bitrate_mbps + " Mbps" : "—" }
                ]
            }
        }

        DetailCard {
            height: Math.max(275, securityFlick.height - 245 - securityCards.spacing)
            title: "Security"

            Column {
                anchors.fill: parent
                spacing: 10

                AdvancedSegmentedRow {
                    height: 40
                    label: "Address policy"
                    value: securityFlick.settings.macPolicy
                    options: [
                        { value: "default", label: "Default" },
                        { value: "stable", label: "Stable" },
                        { value: "random", label: "Random" },
                        { value: "permanent", label: "Permanent" }
                    ]
                    onSelected: function (value) { securityFlick.settings.setMacPolicy(value); }
                }

                DetailGrid {
                    width: parent.width
                    height: 90
                    entries: [
                        { label: "DHCP server", value: securityFlick.settings.dhcpLease.server_identifier || "—" },
                        { label: "Lease duration", value: securityFlick.settings.leaseDurationLabel(securityFlick.settings.dhcpLease.lease_time_seconds) },
                        { label: "Lease domain", value: securityFlick.settings.dhcpLease.domain_name || "—" },
                        { label: "Lease expires", value: securityFlick.settings.leaseExpiryLabel(securityFlick.settings.dhcpLease.expires_at_ms) }
                    ]
                }

                Column {
                    width: parent.width
                    height: 58
                    spacing: 5

                    AdvancedFieldLabel { width: parent.width; height: 13; text: "Network password" }

                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: Theme.controlRadius
                        color: Theme.input
                        border.width: 1
                        border.color: passwordInput.activeFocus ? Theme.strongBorder : Theme.border
                        opacity: securityFlick.settings.personalSecurity ? 1.0 : 0.58

                        TextInput {
                            id: passwordInput

                            anchors.left: parent.left
                            anchors.right: passwordAction.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            leftPadding: 12
                            rightPadding: 10
                            readOnly: !securityFlick.settings.personalSecurity
                            echoMode: securityFlick.settings.passwordRevealed ? TextInput.Normal : TextInput.Password
                            text: securityFlick.settings.passwordValue
                            color: Theme.inputText
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            verticalAlignment: TextInput.AlignVCenter
                            onTextEdited: {
                                securityFlick.settings.passwordValue = text;
                                securityFlick.settings.passwordDirty = true;
                                securityFlick.settings.queueSecuritySave();
                            }

                            Text {
                                anchors.fill: parent
                                leftPadding: 12
                                verticalAlignment: Text.AlignVCenter
                                visible: passwordInput.text.length === 0
                                text: securityFlick.settings.personalSecurity ? "Saved password" : "Unavailable for this security type"
                                color: Theme.subtleText
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                            }
                        }

                        Rectangle {
                            id: passwordAction

                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 98
                            color: passwordActionMouse.containsMouse && passwordActionMouse.enabled ? Theme.hover : "transparent"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 1
                                color: Theme.mix(Theme.border, Theme.text, 0.18)
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 7

                                Text {
                                    text: securityFlick.settings.passwordRevealed ? "󰈉" : "󰈈"
                                    color: Theme.accent
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: securityFlick.settings.controller.advanced.secretLoading ? "Loading" : (securityFlick.settings.passwordRevealed ? "Hide" : "Show")
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }
                            }

                            MouseArea {
                                id: passwordActionMouse

                                anchors.fill: parent
                                enabled: securityFlick.settings.personalSecurity && !securityFlick.settings.controller.advanced.secretLoading
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (securityFlick.settings.passwordRevealed) securityFlick.settings.passwordRevealed = false;
                                    else securityFlick.settings.controller.advanced.revealSecret();
                                }
                            }
                        }
                    }
                }

            }
        }
    }
}

