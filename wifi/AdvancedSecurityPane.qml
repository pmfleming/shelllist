pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui

AdvancedSettingsFlickable {
    id: securityFlick

    required property AdvancedSettingsPage settings

    contentHeight: securityCards.implicitHeight

    Column {
        id: securityCards

        width: securityFlick.width
        spacing: securityFlick.settings.sectionSpacing

        DetailCard {
            height: 245
            title: "Device"
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

        DetailCard {
            height: Math.max(275, securityFlick.height - 245 - securityCards.spacing)
            title: "Security"

            Column {
                id: securityControls
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

                    FieldLabel { width: parent.width; height: 13; text: "Network password" }

                    RowLayout {
                        width: securityControls.width
                        height: 40
                        spacing: 8

                        TextField {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            readOnly: !securityFlick.settings.personalSecurity
                            password: !securityFlick.settings.passwordRevealed
                            text: securityFlick.settings.passwordValue
                            placeholder: securityFlick.settings.personalSecurity
                                ? "Saved password" : "Unavailable for this security type"
                            onEdited: function (value) {
                                securityFlick.settings.passwordValue = value;
                                securityFlick.settings.passwordDirty = true;
                                securityFlick.settings.queueSecuritySave();
                            }
                        }

                        ActionButton {
                            Layout.preferredWidth: 98
                            Layout.fillHeight: true
                            enabled: securityFlick.settings.personalSecurity
                                && !securityFlick.settings.controller.advanced.secretLoading
                            icon: securityFlick.settings.passwordRevealed ? "󰈉" : "󰈈"
                            label: securityFlick.settings.controller.advanced.secretLoading
                                ? "Loading" : (securityFlick.settings.passwordRevealed ? "Hide" : "Show")
                            onClicked: {
                                if (securityFlick.settings.passwordRevealed)
                                    securityFlick.settings.passwordRevealed = false;
                                else
                                    securityFlick.settings.controller.advanced.revealSecret();
                            }
                        }
                    }
                }

            }
        }
    }
}

