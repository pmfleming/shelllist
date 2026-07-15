pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

Item {
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

    readonly property bool securityView: controller.advancedSection === "security"
    readonly property bool personalSecurity: String(profile.security_type || "").indexOf("Personal") >= 0
    readonly property var currentIp: ipFamily === "ipv4" ? (profile.ipv4 || ({})) : (profile.ipv6 || ({}))
    readonly property string currentMethod: ipFamily === "ipv4" ? ipv4Method : ipv6Method
    readonly property bool currentAutoDns: ipFamily === "ipv4" ? ipv4AutoDns : ipv6AutoDns
    readonly property bool editingIpDetails: currentMethod === "manual" || !currentAutoDns
    readonly property var ap: controller.detailAp
    readonly property var status: controller.activeStatus || ({})
    readonly property real density: Math.max(0.76, Math.min(1.0, height / 720))
    readonly property int cardSpacing: Math.max(7, Math.round(10 * density))
    readonly property color cardBorder: Theme.withAlpha(Theme.accent, 0.78)

    clip: true
    focus: visible
    Keys.onEscapePressed: controller.closeAdvancedSettings()

    function firstAddress(settings) {
        return settings && settings.addresses && settings.addresses.length > 0 ? settings.addresses[0] : ({});
    }

    function syncProfile() {
        if (!profile || !profile.path) {
            passwordValue = "";
            passwordDirty = false;
            passwordRevealed = false;
            return;
        }
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
        return {
            method: method,
            addresses: method === "manual" && address.length > 0
                ? [{ address: address, prefix: Math.max(0, parseInt(prefixText || "0", 10) || 0) }]
                : [],
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

    function setMethod(value) {
        if (ipFamily === "ipv4") ipv4Method = value;
        else ipv6Method = value;
    }

    function setAutoDns(value) {
        if (ipFamily === "ipv4") ipv4AutoDns = value === "auto";
        else ipv6AutoDns = value === "auto";
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

    component FieldLabel: Text {
        color: Theme.mutedText
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(12 * page.density)
    }

    component ReadValue: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(13 * page.density)
        elide: Text.ElideRight
    }

    component CardHeading: Row {
        property string icon: ""
        property string title: ""
        height: Math.round(28 * page.density)
        spacing: Math.round(10 * page.density)

        Text {
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: parent.icon
            color: Theme.accent
            font.family: Theme.iconFontFamily
            font.pixelSize: Math.round(21 * page.density)
        }

        Text {
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: parent.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(17 * page.density)
            font.bold: true
        }
    }

    component InfoCard: Rectangle {
        color: Theme.withAlpha(Theme.surfaceRaised, 0.96)
        radius: Theme.cardRadius
        border.width: 1
        border.color: page.cardBorder
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: page.cardSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(70 * page.density)
            spacing: Math.round(10 * page.density)

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(3 * page.density)

                Text {
                    text: "ADVANCED SETTINGS"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(11 * page.density)
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Text {
                    width: parent.width
                    text: page.securityView ? "Security & Privacy" : "Hardware & DNS"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(24 * page.density)
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: page.controller.isActive(page.ap)
                Layout.preferredWidth: Math.round(106 * page.density)
                Layout.preferredHeight: Math.round(34 * page.density)
                Layout.alignment: Qt.AlignVCenter
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.accent

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.accent
                    }

                    Text {
                        text: "Connected"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(12 * page.density)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                id: securityCards
                visible: page.securityView
                anchors.fill: parent
                spacing: page.cardSpacing

                readonly property real usableHeight: height - 2 * spacing

                InfoCard {
                    width: parent.width
                    height: Math.round(securityCards.usableHeight * 0.45)

                    Column {
                        anchors.fill: parent
                        anchors.margins: Math.round(15 * page.density)
                        spacing: Math.max(4, Math.round(7 * page.density))

                        CardHeading { icon: "󰌾"; title: "Security" }
                        FieldLabel { text: "Security type" }
                        ReadValue { width: parent.width; text: page.profile.security_type || "Unknown" }
                        FieldLabel { text: "Network password" }

                        RowLayout {
                            width: parent.width
                            height: 38
                            spacing: 8

                            AdvancedTextField {
                                Layout.fillWidth: true
                                text: page.passwordValue
                                password: !page.passwordRevealed
                                placeholder: page.personalSecurity ? "Saved password" : "Not available for this security type"
                                readOnly: !page.personalSecurity
                                onEdited: function (value) { page.passwordValue = value; page.passwordDirty = true; }
                            }

                            ActionButton {
                                Layout.preferredWidth: 92
                                Layout.preferredHeight: 38
                                icon: page.passwordRevealed ? "󰈉" : "󰈈"
                                label: page.controller.advancedSecretLoading ? "Loading" : (page.passwordRevealed ? "Hide" : "Show")
                                enabled: page.personalSecurity && !page.controller.advancedSecretLoading
                                onClicked: {
                                    if (page.passwordRevealed) page.passwordRevealed = false;
                                    else page.controller.revealAdvancedSecret();
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: page.personalSecurity
                                ? "A new password takes effect the next time NetworkManager activates this profile."
                                : "Password editing is available for WPA Personal profiles."
                            color: Theme.subtleText
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(10 * page.density)
                        }
                    }
                }

                InfoCard {
                    width: parent.width
                    height: Math.round(securityCards.usableHeight * 0.34)

                    Column {
                        anchors.fill: parent
                        anchors.margins: Math.round(15 * page.density)
                        spacing: Math.max(5, Math.round(8 * page.density))

                        CardHeading { icon: "󰈡"; title: "Privacy" }
                        FieldLabel { text: "Address policy" }
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
                            height: Math.round(43 * page.density)

                            Column {
                                Layout.fillWidth: true
                                FieldLabel { text: "Device name sharing" }
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
                    }
                }

                InfoCard {
                    width: parent.width
                    height: securityCards.usableHeight - securityCards.children[0].height - securityCards.children[1].height

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(15 * page.density)
                        spacing: 12

                        CardHeading { icon: "󰍛"; title: "Device identity" }
                        Item { Layout.fillWidth: true }
                        Column {
                            Layout.alignment: Qt.AlignVCenter
                            FieldLabel { text: "Current device MAC" }
                            ReadValue { text: ((page.status.wireless || {}).mac_address || "Unavailable") }
                        }
                    }
                }
            }

            Column {
                id: hardwareCards
                visible: !page.securityView
                anchors.fill: parent
                spacing: page.cardSpacing

                readonly property real usableHeight: height - (page.editingIpDetails ? 0 : 2 * spacing)

                InfoCard {
                    width: parent.width
                    height: page.editingIpDetails ? parent.height : Math.round(hardwareCards.usableHeight * 0.43)

                    Column {
                        anchors.fill: parent
                        anchors.margins: Math.round(15 * page.density)
                        spacing: Math.max(4, Math.round(6 * page.density))

                        RowLayout {
                            width: parent.width
                            CardHeading { icon: "󰖟"; title: "IP & DNS" }
                            Item { Layout.fillWidth: true }
                            AdvancedChoice {
                                Layout.preferredWidth: 105
                                value: page.ipFamily
                                options: [{ value: "ipv4", label: "IPv4" }, { value: "ipv6", label: "IPv6" }]
                                onSelected: function (value) { page.ipFamily = value; }
                            }
                        }

                        GridLayout {
                            width: parent.width
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: Math.max(4, Math.round(6 * page.density))

                            FieldLabel { text: "Assignment" }
                            AdvancedChoice {
                                Layout.fillWidth: true
                                value: page.currentMethod
                                options: [{ value: "auto", label: "Automatic" }, { value: "manual", label: "Manual" }, { value: "disabled", label: "Disabled" }]
                                onSelected: function (value) { page.setMethod(value); }
                            }

                            FieldLabel { text: "DNS source" }
                            AdvancedChoice {
                                Layout.fillWidth: true
                                value: page.currentAutoDns ? "auto" : "manual"
                                options: [{ value: "auto", label: "Automatic" }, { value: "manual", label: "Manual" }]
                                onSelected: function (value) { page.setAutoDns(value); }
                            }

                            FieldLabel { visible: page.currentMethod === "manual"; text: "Address" }
                            AdvancedTextField {
                                visible: page.currentMethod === "manual"
                                Layout.fillWidth: true
                                text: page.ipFamily === "ipv4" ? page.ipv4Address : page.ipv6Address
                                placeholder: page.ipFamily === "ipv4" ? "192.168.1.20" : "2001:db8::20"
                                onEdited: function (value) {
                                    if (page.ipFamily === "ipv4") page.ipv4Address = value;
                                    else page.ipv6Address = value;
                                }
                            }

                            FieldLabel { visible: page.currentMethod === "manual"; text: "Prefix length" }
                            AdvancedTextField {
                                visible: page.currentMethod === "manual"
                                Layout.fillWidth: true
                                text: page.ipFamily === "ipv4" ? page.ipv4Prefix : page.ipv6Prefix
                                onEdited: function (value) {
                                    if (page.ipFamily === "ipv4") page.ipv4Prefix = value;
                                    else page.ipv6Prefix = value;
                                }
                            }

                            FieldLabel { visible: page.currentMethod === "manual"; text: "Gateway" }
                            AdvancedTextField {
                                visible: page.currentMethod === "manual"
                                Layout.fillWidth: true
                                text: page.ipFamily === "ipv4" ? page.ipv4Gateway : page.ipv6Gateway
                                onEdited: function (value) {
                                    if (page.ipFamily === "ipv4") page.ipv4Gateway = value;
                                    else page.ipv6Gateway = value;
                                }
                            }

                            FieldLabel { visible: !page.currentAutoDns; text: "DNS servers" }
                            AdvancedTextField {
                                visible: !page.currentAutoDns
                                Layout.fillWidth: true
                                text: page.ipFamily === "ipv4" ? page.ipv4Dns : page.ipv6Dns
                                placeholder: "Comma-separated addresses"
                                onEdited: function (value) {
                                    if (page.ipFamily === "ipv4") page.ipv4Dns = value;
                                    else page.ipv6Dns = value;
                                }
                            }

                            FieldLabel { text: "DNS search domains" }
                            AdvancedTextField {
                                Layout.fillWidth: true
                                text: page.ipFamily === "ipv4" ? page.ipv4Search : page.ipv6Search
                                placeholder: "Optional, comma-separated"
                                onEdited: function (value) {
                                    if (page.ipFamily === "ipv4") page.ipv4Search = value;
                                    else page.ipv6Search = value;
                                }
                            }
                        }

                        Text {
                            visible: !page.editingIpDetails
                            width: parent.width
                            text: "This network is using automatic IP and DNS settings."
                            color: Theme.subtleText
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(10 * page.density)
                        }
                    }
                }

                InfoCard {
                    visible: !page.editingIpDetails
                    width: parent.width
                    height: Math.round(hardwareCards.usableHeight * 0.31)

                    Column {
                        anchors.fill: parent
                        anchors.margins: Math.round(15 * page.density)
                        spacing: Math.max(4, Math.round(6 * page.density))

                        CardHeading { icon: "󰍛"; title: "Adapter & radio" }

                        Repeater {
                            model: [
                                { label: "Interface", value: page.ap.device_iface || page.status.device_iface || "—" },
                                { label: "Mode", value: page.ap.mode ? "Wi-Fi " + page.ap.mode : "Infrastructure" },
                                { label: "Band / frequency", value: (page.ap.band || "—") + " / " + (page.ap.frequency || "—") + " MHz" },
                                { label: "Channel", value: page.ap.channel === undefined ? "—" : String(page.ap.channel) },
                                { label: "Maximum bitrate", value: page.ap.max_bitrate_mbps ? page.ap.max_bitrate_mbps + " Mbps" : "—" }
                            ]

                            delegate: RowLayout {
                                id: radioRow
                                required property var modelData
                                width: parent.width
                                height: Math.round(17 * page.density)
                                FieldLabel { Layout.preferredWidth: Math.round(150 * page.density); text: radioRow.modelData.label }
                                ReadValue { Layout.fillWidth: true; text: radioRow.modelData.value }
                            }
                        }
                    }
                }

                InfoCard {
                    visible: !page.editingIpDetails
                    width: parent.width
                    height: hardwareCards.usableHeight - hardwareCards.children[0].height - hardwareCards.children[1].height

                    Column {
                        anchors.fill: parent
                        anchors.margins: Math.round(15 * page.density)
                        spacing: Math.max(4, Math.round(6 * page.density))

                        CardHeading { icon: "󰘚"; title: "Identifiers" }

                        Repeater {
                            model: [
                                { label: "BSSID", value: page.ap.bssid || "—" },
                                { label: "Device MAC", value: ((page.status.wireless || {}).mac_address || "—") },
                                { label: "Profile path", value: page.profile.path || "—" }
                            ]

                            delegate: RowLayout {
                                id: identifierRow
                                required property var modelData
                                width: parent.width
                                height: Math.round(19 * page.density)
                                FieldLabel { Layout.preferredWidth: Math.round(150 * page.density); text: identifierRow.modelData.label }
                                ReadValue { Layout.fillWidth: true; text: identifierRow.modelData.value }
                            }
                        }
                    }
                }
            }

            Text {
                visible: page.controller.advancedLoading
                anchors.centerIn: parent
                text: "Loading saved profile…"
                color: Theme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: page.controller.advancedError
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            ActionButton {
                Layout.preferredWidth: 88
                Layout.preferredHeight: 38
                label: "Cancel"
                enabled: !page.controller.advancedSaving
                onClicked: page.controller.closeAdvancedSettings()
            }

            ActionButton {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 38
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
