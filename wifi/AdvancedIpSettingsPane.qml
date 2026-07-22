pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."
import "networkinput" as NetworkInput
import Shelllist.Ui

AdvancedSettingsFlickable {
    id: hardwareFlick

    required property var settings

    contentHeight: hardwareCards.implicitHeight

    Column {
        id: hardwareCards

        width: hardwareFlick.width
        spacing: hardwareFlick.settings.sectionSpacing

        DetailCard {
            height: Math.max(500, hardwareFlick.height)
            title: "IP & DNS"

            Column {
                anchors.fill: parent
                spacing: 10

                AdvancedSegmentedRow {
                    label: "Address family"
                    value: hardwareFlick.settings.ipFamily
                    options: [
                        { value: "ipv4", label: "IPv4" },
                        { value: "ipv6", label: "IPv6" }
                    ]
                    onSelected: function (value) { hardwareFlick.settings.ipFamily = value; }
                }

                ToggleRow {
                    width: parent.width
                    height: 44
                    title: hardwareFlick.settings.ipFamily === "ipv4" ? "Enable IPv4" : "Enable IPv6"
                    showSubtitle: false
                    checked: hardwareFlick.settings.currentFamilyEnabled
                    onClicked: hardwareFlick.settings.setMethod(hardwareFlick.settings.currentFamilyEnabled ? "disabled" : "auto")
                }

                ToggleRow {
                    width: parent.width
                    height: 44
                    title: "Automatic addressing"
                    showSubtitle: false
                    checked: hardwareFlick.settings.currentMethod === "auto"
                    interactive: hardwareFlick.settings.currentFamilyEnabled
                    onClicked: hardwareFlick.settings.setMethod(hardwareFlick.settings.currentMethod === "auto" ? "manual" : "auto")
                }

                ToggleRow {
                    width: parent.width
                    height: 44
                    title: "Automatic DNS"
                    showSubtitle: false
                    checked: hardwareFlick.settings.currentAutoDns
                    interactive: hardwareFlick.settings.currentFamilyEnabled
                    onClicked: hardwareFlick.settings.setAutoDns(!hardwareFlick.settings.currentAutoDns)
                }

                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 8

                    FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "IP address" }
                    NetworkInput.IpAddressField {
                        Layout.fillWidth: true
                        family: hardwareFlick.settings.ipFamily
                        allowEmpty: hardwareFlick.settings.currentMethod !== "manual"
                        readOnly: hardwareFlick.settings.currentMethod !== "manual"
                        text: hardwareFlick.settings.displayedAddress
                        onEdited: function (value) {
                            if (hardwareFlick.settings.ipFamily === "ipv4") hardwareFlick.settings.ipv4Address = value;
                            else hardwareFlick.settings.ipv6Address = value;
                        }
                        onEditingFinished: hardwareFlick.settings.queueHardwareSave()
                    }

                    FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "Prefix length" }
                    NetworkInput.PrefixLengthField {
                        Layout.fillWidth: true
                        family: hardwareFlick.settings.ipFamily
                        allowEmpty: hardwareFlick.settings.currentMethod !== "manual"
                        readOnly: hardwareFlick.settings.currentMethod !== "manual"
                        text: hardwareFlick.settings.displayedPrefix
                        onEdited: function (value) {
                            if (hardwareFlick.settings.ipFamily === "ipv4") hardwareFlick.settings.ipv4Prefix = value;
                            else hardwareFlick.settings.ipv6Prefix = value;
                        }
                        onEditingFinished: hardwareFlick.settings.queueHardwareSave()
                    }

                    FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "Gateway" }
                    NetworkInput.IpAddressField {
                        Layout.fillWidth: true
                        family: hardwareFlick.settings.ipFamily
                        readOnly: hardwareFlick.settings.currentMethod !== "manual"
                        text: hardwareFlick.settings.displayedGateway
                        onEdited: function (value) {
                            if (hardwareFlick.settings.ipFamily === "ipv4") hardwareFlick.settings.ipv4Gateway = value;
                            else hardwareFlick.settings.ipv6Gateway = value;
                        }
                        onEditingFinished: hardwareFlick.settings.queueHardwareSave()
                    }

                    FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "DNS servers" }
                    NetworkInput.IpAddressField {
                        Layout.fillWidth: true
                        family: hardwareFlick.settings.ipFamily
                        multiple: true
                        readOnly: !hardwareFlick.settings.currentFamilyEnabled || hardwareFlick.settings.currentAutoDns
                        text: hardwareFlick.settings.displayedDns
                        onEdited: function (value) {
                            if (hardwareFlick.settings.ipFamily === "ipv4") hardwareFlick.settings.ipv4Dns = value;
                            else hardwareFlick.settings.ipv6Dns = value;
                        }
                        onEditingFinished: hardwareFlick.settings.queueHardwareSave()
                    }

                    FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "DNS search domains" }
                    TextField {
                        Layout.fillWidth: true
                        readOnly: !hardwareFlick.settings.currentFamilyEnabled
                        text: hardwareFlick.settings.ipFamily === "ipv4" ? hardwareFlick.settings.ipv4Search : hardwareFlick.settings.ipv6Search
                        placeholder: "Optional, comma-separated"
                        onEdited: function (value) {
                            if (hardwareFlick.settings.ipFamily === "ipv4") hardwareFlick.settings.ipv4Search = value;
                            else hardwareFlick.settings.ipv6Search = value;
                        }
                        onEditingFinished: hardwareFlick.settings.queueHardwareSave()
                    }
                }
            }
        }

    }
}

