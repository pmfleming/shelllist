pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: page

    required property var controller

    property var profile: controller.advancedProfile
    property bool autoconnect: true
    property string metered: "auto"
    property bool hiddenNetwork: false
    property string macPolicy: "default"
    property bool sendHostname: true
    property string passwordValue: ""
    property bool passwordDirty: false
    property bool passwordRevealed: false
    property string ipFamily: "ipv4"
    property string ipv4Method: "auto"
    property string ipv4Address: ""
    property string ipv4Prefix: "24"
    property string ipv4Gateway: ""
    property bool ipv4AutoDns: true
    property string ipv4Dns: ""
    property string ipv4Search: ""
    property string ipv6Method: "auto"
    property string ipv6Address: ""
    property string ipv6Prefix: "64"
    property string ipv6Gateway: ""
    property bool ipv6AutoDns: true
    property string ipv6Dns: ""
    property string ipv6Search: ""

    readonly property bool personalSecurity: String(profile.security_type || "").indexOf("Personal") >= 0
    readonly property var currentIp: ipFamily === "ipv4" ? (profile.ipv4 || ({})) : (profile.ipv6 || ({}))
    readonly property string currentMethod: ipFamily === "ipv4" ? ipv4Method : ipv6Method
    readonly property bool currentAutoDns: ipFamily === "ipv4" ? ipv4AutoDns : ipv6AutoDns
    readonly property var ap: controller.detailAp
    readonly property var status: controller.activeStatus || ({})

    color: Theme.window
    radius: Theme.windowRadius
    border.color: Theme.strongBorder
    border.width: 1
    focus: visible
    Keys.onEscapePressed: controller.closeAdvancedSettings()

    function firstAddress(settings) {
        return settings && settings.addresses && settings.addresses.length > 0 ? settings.addresses[0] : ({});
    }

    function syncProfile() {
        if (!profile || !profile.path)
            return;
        autoconnect = !!profile.autoconnect;
        metered = profile.metered || "auto";
        hiddenNetwork = !!profile.hidden;
        macPolicy = profile.mac_address_policy || "default";
        sendHostname = profile.send_hostname !== false;
        const ipv4 = profile.ipv4 || ({});
        const ipv6 = profile.ipv6 || ({});
        const address4 = firstAddress(ipv4);
        const address6 = firstAddress(ipv6);
        ipv4Method = ipv4.method || "auto";
        ipv4Address = address4.address || "";
        ipv4Prefix = String(address4.prefix === undefined ? 24 : address4.prefix);
        ipv4Gateway = ipv4.gateway || "";
        ipv4AutoDns = !ipv4.ignore_auto_dns;
        ipv4Dns = (ipv4.dns || []).join(", ");
        ipv4Search = (ipv4.dns_search || []).join(", ");
        ipv6Method = ipv6.method || "auto";
        ipv6Address = address6.address || "";
        ipv6Prefix = String(address6.prefix === undefined ? 64 : address6.prefix);
        ipv6Gateway = ipv6.gateway || "";
        ipv6AutoDns = !ipv6.ignore_auto_dns;
        ipv6Dns = (ipv6.dns || []).join(", ");
        ipv6Search = (ipv6.dns_search || []).join(", ");
        passwordValue = "";
        passwordDirty = false;
        passwordRevealed = false;
    }

    function splitValues(value) {
        return String(value || "").split(/[\s,]+/).filter(function (entry) { return entry.length > 0; });
    }

    function buildIp(family, source) {
        const method = family === "ipv4" ? ipv4Method : ipv6Method;
        const address = family === "ipv4" ? ipv4Address.trim() : ipv6Address.trim();
        const prefixText = family === "ipv4" ? ipv4Prefix : ipv6Prefix;
        const gateway = family === "ipv4" ? ipv4Gateway.trim() : ipv6Gateway.trim();
        const autoDns = family === "ipv4" ? ipv4AutoDns : ipv6AutoDns;
        const dnsText = family === "ipv4" ? ipv4Dns : ipv6Dns;
        const searchText = family === "ipv4" ? ipv4Search : ipv6Search;
        const addresses = method === "manual" && address.length > 0
            ? [{ address: address, prefix: Math.max(0, parseInt(prefixText || "0", 10) || 0) }]
            : [];
        return {
            method: method,
            addresses: addresses,
            gateway: gateway.length > 0 ? gateway : null,
            dns: autoDns ? [] : splitValues(dnsText),
            routes: source.routes || [],
            route_metric: source.route_metric === undefined ? null : source.route_metric,
            ignore_auto_dns: !autoDns,
            dns_search: splitValues(searchText)
        };
    }

    function save() {
        controller.saveAdvancedSettings({
            autoconnect: autoconnect,
            metered: metered,
            hidden: hiddenNetwork,
            mac_address_policy: macPolicy,
            send_hostname: sendHostname,
            ipv4: buildIp("ipv4", profile.ipv4 || ({})),
            ipv6: buildIp("ipv6", profile.ipv6 || ({})),
            password: passwordDirty && passwordValue.length > 0 ? passwordValue : null
        });
    }

    onProfileChanged: syncProfile()

    Connections {
        target: page.controller
        function onAdvancedSecretChanged() {
            if (page.controller.advancedSecret.length === 0)
                return;
            page.passwordValue = page.controller.advancedSecret;
            page.passwordDirty = false;
            page.passwordRevealed = true;
        }
    }

    component SectionHeading: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 20
        font.bold: true
    }

    component FieldLabel: Text {
        color: Theme.mutedText
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    component ReadValue: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            spacing: 12

            IconTile {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                icon: "󰁍"
                iconColor: Theme.text
                iconSize: 19
                backgroundColor: Theme.surfaceRaised
                borderColor: Theme.border
                clickable: true
                onClicked: page.controller.closeAdvancedSettings()
            }

            SignalIcon {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 32
                level: 3
                iconColor: Theme.accent
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: "Advanced settings — " + (page.profile.ssid || page.controller.networkName(page.ap))
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    text: page.profile.id ? "Saved profile: " + page.profile.id : "Loading saved profile…"
                    color: Theme.subtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 190
                Layout.fillHeight: true
                radius: Theme.cardRadius
                color: Theme.withAlpha(Theme.surfaceRaised, 0.96)
                border.color: Theme.mix(Theme.border, Theme.text, 0.12)

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "general", label: "General", icon: "󰒓" },
                            { id: "security", label: "Security", icon: "󰌾" },
                            { id: "privacy", label: "Privacy", icon: "󰈡" },
                            { id: "ip", label: "IP & DNS", icon: "󰩠" },
                            { id: "hardware", label: "Hardware details", icon: "󰍹" }
                        ]

                        delegate: Rectangle {
                            id: navItem

                            required property var modelData

                            width: parent.width
                            height: 42
                            radius: Theme.controlRadius
                            color: page.controller.advancedSection === navItem.modelData.id ? Theme.selected : "transparent"
                            border.color: page.controller.advancedSection === navItem.modelData.id ? Theme.strongBorder : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                spacing: 10

                                Text {
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                    text: navItem.modelData.icon
                                    color: page.controller.advancedSection === navItem.modelData.id ? Theme.accent : Theme.mutedText
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: 16
                                }

                                Text {
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                    text: navItem.modelData.label
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.controller.advancedSection = navItem.modelData.id
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.cardRadius
                color: Theme.withAlpha(Theme.surfaceRaised, 0.96)
                border.color: Theme.mix(Theme.border, Theme.text, 0.12)
                clip: true

                Item {
                    anchors.fill: parent
                    anchors.margins: 20

                    Column {
                        visible: page.controller.advancedSection === "general"
                        width: parent.width
                        spacing: 14

                        SectionHeading { text: "General" }

                        RowLayout {
                            width: parent.width
                            height: 42
                            FieldLabel { Layout.preferredWidth: 180; text: "Network name (SSID)" }
                            ReadValue { Layout.fillWidth: true; text: page.profile.ssid || "—" }
                        }

                        RowLayout {
                            width: parent.width
                            height: 48

                            Column {
                                Layout.fillWidth: true
                                FieldLabel { text: "Connect automatically" }
                                ReadValue { text: "Connect whenever this network is in range" }
                            }

                            TogglePill {
                                checked: page.autoconnect
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.autoconnect = !page.autoconnect
                                }
                            }
                        }

                        RowLayout {
                            width: parent.width
                            height: 48

                            Column {
                                Layout.fillWidth: true
                                FieldLabel { text: "Metered connection" }
                                ReadValue { text: "Allow applications to reduce background data usage" }
                            }

                            AdvancedChoice {
                                Layout.preferredWidth: 150
                                value: page.metered
                                options: [{ value: "auto", label: "Automatic" }, { value: "no", label: "Not metered" }, { value: "yes", label: "Metered" }]
                                onSelected: function (value) { page.metered = value; }
                            }
                        }

                        RowLayout {
                            width: parent.width
                            height: 48

                            Column {
                                Layout.fillWidth: true
                                FieldLabel { text: "Hidden network" }
                                ReadValue { text: "Connect even when the SSID is not broadcasting" }
                            }

                            TogglePill {
                                checked: page.hiddenNetwork
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.hiddenNetwork = !page.hiddenNetwork
                                }
                            }
                        }
                    }

                    Column {
                        visible: page.controller.advancedSection === "security"
                        width: parent.width
                        spacing: 14

                        SectionHeading { text: "Security" }
                        FieldLabel { text: "Security type" }
                        AdvancedTextField { width: parent.width; text: page.profile.security_type || "Unknown"; readOnly: true }
                        FieldLabel { text: "Network password" }

                        RowLayout {
                            width: parent.width
                            AdvancedTextField { Layout.fillWidth: true; text: page.passwordValue; password: !page.passwordRevealed; placeholder: page.personalSecurity ? "Saved password" : "Not available for this security type"; readOnly: !page.personalSecurity; onEdited: function (value) { page.passwordValue = value; page.passwordDirty = true; } }
                            ActionButton {
                                Layout.preferredWidth: 110
                                icon: page.passwordRevealed ? "󰈉" : "󰈈"
                                label: page.controller.advancedSecretLoading ? "Loading" : (page.passwordRevealed ? "Hide" : "Show")
                                enabled: page.personalSecurity && !page.controller.advancedSecretLoading
                                onClicked: {
                                    if (page.passwordRevealed)
                                        page.passwordRevealed = false;
                                    else
                                        page.controller.revealAdvancedSecret();
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: page.personalSecurity
                                ? "Entering a new WPA Personal password updates the saved profile. The change takes effect the next time NetworkManager activates it."
                                : "Password editing is currently available only for WPA Personal profiles."
                            color: Theme.subtleText
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    Column {
                        visible: page.controller.advancedSection === "privacy"
                        width: parent.width
                        spacing: 14

                        SectionHeading { text: "Privacy" }
                        FieldLabel { text: "Hardware address policy" }
                        AdvancedChoice {
                            width: parent.width
                            value: page.macPolicy
                            options: [
                                { value: "default", label: "System default" },
                                { value: "stable", label: "Stable private address" },
                                { value: "random", label: "New random address each connection" },
                                { value: "permanent", label: "Permanent device address" }
                            ]
                            onSelected: function (value) { page.macPolicy = value; }
                        }

                        RowLayout {
                            width: parent.width
                            height: 54

                            Column {
                                Layout.fillWidth: true
                                FieldLabel { text: "Send device name" }
                                ReadValue { text: "Share this device's hostname with the network" }
                            }

                            TogglePill {
                                checked: page.sendHostname
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.sendHostname = !page.sendHostname
                                }
                            }
                        }

                        FieldLabel { text: "Current device MAC" }
                        AdvancedTextField { width: parent.width; text: ((page.status.wireless || {}).mac_address || "Unavailable"); readOnly: true }
                    }

                    Column {
                        visible: page.controller.advancedSection === "ip"
                        width: parent.width
                        spacing: 11

                        RowLayout {
                            width: parent.width
                            SectionHeading { Layout.fillWidth: true; text: "IP & DNS" }
                            AdvancedChoice { Layout.preferredWidth: 120; value: page.ipFamily; options: [{ value: "ipv4", label: "IPv4" }, { value: "ipv6", label: "IPv6" }]; onSelected: function (value) { page.ipFamily = value; } }
                        }

                        GridLayout {
                            width: parent.width
                            columns: 2
                            columnSpacing: 14
                            rowSpacing: 9

                            Column {
                                Layout.fillWidth: true
                                FieldLabel { text: "Assignment" }
                                AdvancedChoice {
                                    width: parent.width
                                    value: page.currentMethod
                                    options: [{ value: "auto", label: "Automatic (DHCP)" }, { value: "manual", label: "Manual" }, { value: "disabled", label: "Disabled" }]
                                    onSelected: function (value) {
                                        if (page.ipFamily === "ipv4") page.ipv4Method = value;
                                        else page.ipv6Method = value;
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                FieldLabel { text: "DNS source" }
                                AdvancedChoice {
                                    width: parent.width
                                    value: page.currentAutoDns ? "auto" : "manual"
                                    options: [{ value: "auto", label: "Automatic" }, { value: "manual", label: "Manual" }]
                                    onSelected: function (value) {
                                        if (page.ipFamily === "ipv4") page.ipv4AutoDns = value === "auto";
                                        else page.ipv6AutoDns = value === "auto";
                                    }
                                }
                            }

                            Column {
                                visible: page.currentMethod === "manual"
                                Layout.fillWidth: true
                                FieldLabel { text: "Address" }
                                AdvancedTextField {
                                    width: parent.width
                                    text: page.ipFamily === "ipv4" ? page.ipv4Address : page.ipv6Address
                                    placeholder: page.ipFamily === "ipv4" ? "192.168.1.20" : "2001:db8::20"
                                    onEdited: function (value) {
                                        if (page.ipFamily === "ipv4") page.ipv4Address = value;
                                        else page.ipv6Address = value;
                                    }
                                }
                            }

                            Column {
                                visible: page.currentMethod === "manual"
                                Layout.fillWidth: true
                                FieldLabel { text: "Prefix length" }
                                AdvancedTextField {
                                    width: parent.width
                                    text: page.ipFamily === "ipv4" ? page.ipv4Prefix : page.ipv6Prefix
                                    onEdited: function (value) {
                                        if (page.ipFamily === "ipv4") page.ipv4Prefix = value;
                                        else page.ipv6Prefix = value;
                                    }
                                }
                            }

                            Column {
                                visible: page.currentMethod === "manual"
                                Layout.fillWidth: true
                                FieldLabel { text: "Gateway" }
                                AdvancedTextField {
                                    width: parent.width
                                    text: page.ipFamily === "ipv4" ? page.ipv4Gateway : page.ipv6Gateway
                                    onEdited: function (value) {
                                        if (page.ipFamily === "ipv4") page.ipv4Gateway = value;
                                        else page.ipv6Gateway = value;
                                    }
                                }
                            }

                            Column {
                                visible: !page.currentAutoDns
                                Layout.fillWidth: true
                                FieldLabel { text: "DNS servers" }
                                AdvancedTextField {
                                    width: parent.width
                                    text: page.ipFamily === "ipv4" ? page.ipv4Dns : page.ipv6Dns
                                    placeholder: "Comma-separated addresses"
                                    onEdited: function (value) {
                                        if (page.ipFamily === "ipv4") page.ipv4Dns = value;
                                        else page.ipv6Dns = value;
                                    }
                                }
                            }

                            Column {
                                Layout.columnSpan: 2
                                Layout.fillWidth: true
                                FieldLabel { text: "DNS search domains" }
                                AdvancedTextField {
                                    width: parent.width
                                    text: page.ipFamily === "ipv4" ? page.ipv4Search : page.ipv6Search
                                    placeholder: "Optional, comma-separated"
                                    onEdited: function (value) {
                                        if (page.ipFamily === "ipv4") page.ipv4Search = value;
                                        else page.ipv6Search = value;
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        visible: page.controller.advancedSection === "hardware"
                        width: parent.width
                        spacing: 10

                        SectionHeading { text: "Hardware details" }

                        Repeater {
                            model: [
                                { label: "Interface", value: page.ap.device_iface || page.status.device_iface || "—" },
                                { label: "BSSID", value: page.ap.bssid || "—" },
                                { label: "Protocol", value: page.ap.mode ? "Wi-Fi " + page.ap.mode : "Wi-Fi" },
                                { label: "Band / frequency", value: (page.ap.band || "—") + " / " + (page.ap.frequency || "—") + " MHz" },
                                { label: "Channel", value: page.ap.channel === undefined ? "—" : String(page.ap.channel) },
                                { label: "Maximum bitrate", value: page.ap.max_bitrate_mbps ? page.ap.max_bitrate_mbps + " Mbps" : "—" },
                                { label: "Device MAC", value: ((page.status.wireless || {}).mac_address || "—") },
                                { label: "Profile path", value: page.profile.path || "—" }
                            ]

                            delegate: RowLayout {
                                id: hardwareRow

                                required property var modelData
                                width: parent.width
                                height: 32
                                FieldLabel { Layout.preferredWidth: 180; text: hardwareRow.modelData.label }
                                ReadValue { Layout.fillWidth: true; text: hardwareRow.modelData.value }
                            }
                        }
                    }

                    Text {
                        visible: page.controller.advancedLoading
                        anchors.centerIn: parent
                        text: "Loading advanced profile…"
                        color: Theme.mutedText
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: page.controller.advancedError
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            ActionButton {
                Layout.preferredWidth: 100
                label: "Cancel"
                enabled: !page.controller.advancedSaving
                onClicked: page.controller.closeAdvancedSettings()
            }

            ActionButton {
                Layout.preferredWidth: 110
                icon: "󰆓"
                label: page.controller.advancedSaving ? "Saving" : "Save"
                backgroundColor: Theme.accent
                borderColor: Theme.accent
                labelColor: Theme.accentText
                enabled: !!page.profile.path && !page.controller.advancedLoading && !page.controller.advancedSaving
                onClicked: page.save()
            }
        }
    }
}
