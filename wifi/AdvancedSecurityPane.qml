pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui
import "WifiPresentation.js" as Presentation

AdvancedSettingsFlickable {
    id: securityFlick
    required property AdvancedSettingsPage settings
    viewMemory: settings.controller.viewMemory
    memoryTab: "security"
    contentHeight: securityCards.implicitHeight

    Column {
        id: securityCards
        width: securityFlick.width
        spacing: securityFlick.settings.sectionSpacing
        DetailColumnCard {
            objectName: "wifiSecurityControls"
            height: implicitHeight
            title: qsTr("Security & privacy")
            Column {
                id: securityControls
                Layout.fillWidth: true
                spacing: 10
                AdvancedSegmentedRow {
                    visible: !!securityFlick.settings.bandStatus.path
                    height: visible ? 40 : 0
                    enabled: !securityFlick.settings.controller.actionInFlight
                    objectName: "wifiBand"
                    label: qsTr("Wi-Fi band")
                    value: securityFlick.settings.bandStatus.selected || "auto"
                    options: [
                        {
                            value: "auto",
                            label: qsTr("Auto")
                        },
                        {
                            value: "2.4",
                            label: "2.4 GHz",
                            enabled: (securityFlick.settings.bandStatus.available || []).indexOf("2.4") >= 0
                        },
                        {
                            value: "5",
                            label: "5 GHz",
                            enabled: (securityFlick.settings.bandStatus.available || []).indexOf("5") >= 0
                        },
                        {
                            value: "6",
                            label: "6 GHz",
                            enabled: (securityFlick.settings.bandStatus.available || []).indexOf("6") >= 0
                        }
                    ]
                    onSelected: function (value) {
                        securityFlick.settings.setBand(value);
                    }
                }
                AdvancedSegmentedRow {
                    height: 40
                    objectName: "wifiMacPolicy"
                    label: qsTr("Address policy")
                    value: securityFlick.settings.macPolicy
                    options: [
                        {
                            value: "default",
                            label: qsTr("Default")
                        },
                        {
                            value: "stable",
                            label: qsTr("Stable")
                        },
                        {
                            value: "random",
                            label: qsTr("Random")
                        },
                        {
                            value: "permanent",
                            label: qsTr("Permanent")
                        }
                    ]
                    onSelected: function (value) {
                        securityFlick.settings.setMacPolicy(value);
                    }
                }
                ToggleRow {
                    objectName: "castingToggle"
                    height: 40
                    title: qsTr("Cast discovery")
                    checked: securityFlick.settings.castingEnabled
                    enabled: !!securityFlick.settings.profile.path && !securityFlick.settings.controller.actionInFlight
                    onClicked: securityFlick.settings.setCastingEnabled(!checked)
                }
                Column {
                    width: parent.width
                    spacing: 5
                    FieldLabel {
                        width: parent.width
                        text: qsTr("Network password")
                    }
                    TextField {
                        sensitive: true
                        width: securityControls.width
                        height: 40
                        readOnly: !securityFlick.settings.personalSecurity
                        password: !securityFlick.settings.passwordRevealed
                        showPasswordButton: false
                        text: securityFlick.settings.passwordValue
                        placeholder: securityFlick.settings.personalSecurity ? qsTr("Saved password") : qsTr("Unavailable for this security type")
                        trailingActionIcon: securityFlick.settings.personalSecurity ? (securityFlick.settings.passwordRevealed ? "󰈉" : "󰈈") : ""
                        trailingActionToolTip: securityFlick.settings.controller.advanced.secretLoading ? qsTr("Loading password") : (securityFlick.settings.passwordRevealed ? qsTr("Hide password") : qsTr("Show password"))
                        trailingActionEnabled: securityFlick.settings.personalSecurity && !securityFlick.settings.controller.advanced.secretLoading
                        onEdited: function (value) {
                            securityFlick.settings.passwordValue = value;
                            securityFlick.settings.passwordDirty = true;
                            securityFlick.settings.queueSecuritySave();
                        }
                        onTrailingActionRequested: {
                            if (securityFlick.settings.passwordRevealed)
                                securityFlick.settings.passwordRevealed = false;
                            else
                                securityFlick.settings.controller.advanced.revealSecret();
                        }
                    }
                }
            }
        }
        DisclosureSection {
            objectName: "wifiSecurityDiagnostics"
            title: qsTr("Device & DHCP details")
            DetailCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 350
                title: qsTr("Technical details")
                entries: [
                    {
                        label: "BSSID",
                        value: securityFlick.settings.ap.bssid || "—"
                    },
                    {
                        label: qsTr("Device MAC"),
                        value: (securityFlick.settings.status.wireless || {}).mac_address || "—"
                    },
                    {
                        label: qsTr("Profile path"),
                        value: securityFlick.settings.profile.path || "—"
                    },
                    {
                        label: qsTr("Interface"),
                        value: securityFlick.settings.ap.device_iface || securityFlick.settings.status.device_iface || "—"
                    },
                    {
                        label: qsTr("Mode"),
                        value: securityFlick.settings.ap.mode ? "Wi-Fi " + securityFlick.settings.ap.mode : qsTr("Infrastructure")
                    },
                    {
                        label: qsTr("Band / frequency"),
                        value: (securityFlick.settings.ap.band || "—") + " / " + (securityFlick.settings.ap.frequency || "—") + " MHz"
                    },
                    {
                        label: qsTr("Channel"),
                        value: securityFlick.settings.ap.channel === undefined ? "—" : String(securityFlick.settings.ap.channel)
                    },
                    {
                        label: qsTr("Maximum bitrate"),
                        value: securityFlick.settings.ap.max_bitrate_mbps ? securityFlick.settings.ap.max_bitrate_mbps + " Mbps" : "—"
                    },
                    {
                        label: qsTr("DHCP server"),
                        value: securityFlick.settings.dhcpLease.server_identifier || "—"
                    },
                    {
                        label: qsTr("Lease duration"),
                        value: Presentation.leaseDurationLabel(securityFlick.settings.dhcpLease.lease_time_seconds)
                    },
                    {
                        label: qsTr("Lease domain"),
                        value: securityFlick.settings.dhcpLease.domain_name || "—"
                    },
                    {
                        label: qsTr("Lease expires"),
                        value: Presentation.leaseExpiryLabel(securityFlick.settings.dhcpLease.expires_at_ms)
                    }
                ]
            }
        }
    }
}
