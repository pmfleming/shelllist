pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: page

    required property var controller

    property var profile: controller.advancedProfile
    property int sectionSpacing: 12
    property string macPolicy
    property bool sendHostname
    property string passwordValue
    property bool passwordDirty
    property bool passwordRevealed
    property bool securityDirty
    property string ipFamily
    property string ipv4Method
    property string ipv4Address
    property string ipv4Prefix
    property string ipv4Gateway
    property bool ipv4AutoDns
    property string ipv4Dns
    property string ipv4Search
    property string ipv6Method
    property string ipv6Address
    property string ipv6Prefix
    property string ipv6Gateway
    property bool ipv6AutoDns
    property string ipv6Dns
    property string ipv6Search
    property bool hardwareDirty

    readonly property bool securityView: controller.advancedSection === "security"
    readonly property bool personalSecurity: String(profile.security_type || "").indexOf("Personal") >= 0
    readonly property string currentMethod: ipFamily === "ipv4" ? ipv4Method : ipv6Method
    readonly property bool currentAutoDns: ipFamily === "ipv4" ? ipv4AutoDns : ipv6AutoDns
    readonly property var ap: controller.detailAp
    readonly property var status: controller.activeStatus || ({})
    readonly property int ipRowCount: 3 + (currentMethod === "manual" ? 3 : 0) + (!currentAutoDns ? 1 : 0)
    readonly property int ipCardHeight: 116 + ipRowCount * 38 + Math.max(0, ipRowCount - 1) * 8

    clip: true
    focus: visible
    Keys.onEscapePressed: controller.closeAdvancedSettings()

    function firstAddress(settings) {
        return settings && settings.addresses && settings.addresses.length > 0 ? settings.addresses[0] : ({});
    }

    function resetEditState() {
        autoSaveTimer.stop();
        passwordValue = "";
        passwordDirty = false;
        passwordRevealed = false;
        securityDirty = false;
        hardwareDirty = false;
    }

    function syncIp(family, fallbackPrefix) {
        const settings = profile[family] || ({});
        const address = firstAddress(settings);
        page[family + "Method"] = settings.method || "auto";
        page[family + "Address"] = address.address || "";
        page[family + "Prefix"] = String(address.prefix === undefined ? fallbackPrefix : address.prefix);
        page[family + "Gateway"] = settings.gateway || "";
        page[family + "AutoDns"] = !settings.ignore_auto_dns;
        page[family + "Dns"] = (settings.dns || []).join(", ");
        page[family + "Search"] = (settings.dns_search || []).join(", ");
    }

    function syncProfile() {
        resetEditState();
        if (!profile || !profile.path)
            return;
        macPolicy = profile.mac_address_policy || "default";
        sendHostname = profile.send_hostname !== false;
        syncIp("ipv4", 24);
        syncIp("ipv6", 64);
    }

    function splitValues(value) {
        return String(value || "").split(/[\s,]+/).filter(function (entry) { return entry.length > 0; });
    }

    function ipValue(family, name) { return page[family + name]; }

    function buildIp(family, source) {
        const method = ipValue(family, "Method");
        const address = ipValue(family, "Address").trim();
        const prefix = Math.max(0, parseInt(ipValue(family, "Prefix") || "0", 10) || 0);
        const gateway = ipValue(family, "Gateway").trim();
        const automaticDns = ipValue(family, "AutoDns");
        return {
            method: method,
            addresses: method === "manual" && address.length > 0 ? [{ address: address, prefix: prefix }] : [],
            gateway: gateway.length > 0 ? gateway : null,
            dns: automaticDns ? [] : splitValues(ipValue(family, "Dns")),
            routes: source.routes || [],
            route_metric: source.route_metric === undefined ? null : source.route_metric,
            ignore_auto_dns: !automaticDns,
            dns_search: splitValues(ipValue(family, "Search"))
        };
    }

    function queueSecuritySave() {
        securityDirty = true;
        autoSaveTimer.restart();
    }

    function queueHardwareSave() {
        hardwareDirty = true;
        autoSaveTimer.restart();
    }

    function saveDirty() {
        if ((!securityDirty && !hardwareDirty) || !profile.path)
            return;
        if (controller.advancedSaving || controller.advancedLoading) {
            autoSaveTimer.restart();
            return;
        }

        const origin = securityDirty && !hardwareDirty ? "security" : (hardwareDirty && !securityDirty ? "hardware" : controller.advancedSection);
        const accepted = controller.saveAdvancedSettings({
            autoconnect: !!profile.autoconnect,
            metered: profile.metered || "auto",
            hidden: !!profile.hidden,
            mac_address_policy: macPolicy,
            send_hostname: sendHostname,
            ipv4: buildIp("ipv4", profile.ipv4 || ({})),
            ipv6: buildIp("ipv6", profile.ipv6 || ({})),
            password: passwordDirty && passwordValue.length > 0 ? passwordValue : null
        }, origin);
        if (!accepted) {
            autoSaveTimer.restart();
            return;
        }

        securityDirty = false;
        hardwareDirty = false;
        passwordDirty = false;
    }

    function setMethod(value) {
        if (value === currentMethod)
            return;
        if (ipFamily === "ipv4") ipv4Method = value;
        else ipv6Method = value;
        queueHardwareSave();
    }

    function setAutoDns(value) {
        const automatic = value === "auto";
        if (automatic === currentAutoDns)
            return;
        if (ipFamily === "ipv4") ipv4AutoDns = automatic;
        else ipv6AutoDns = automatic;
        queueHardwareSave();
    }

    Component.onCompleted: {
        ipFamily = "ipv4";
        syncProfile();
    }
    onProfileChanged: {
        if (!securityDirty && !hardwareDirty)
            syncProfile();
    }

    Timer {
        id: autoSaveTimer
        interval: 700
        repeat: false
        onTriggered: page.saveDirty()
    }

    Connections {
        target: page.controller

        function onAdvancedSecretChanged() {
            if (page.controller.advancedSecret.length === 0)
                return;
            page.passwordValue = page.controller.advancedSecret;
            page.passwordDirty = false;
            page.passwordRevealed = true;
        }

        function onAdvancedSectionLeaving() {
            autoSaveTimer.stop();
            page.saveDirty();
        }

        function onAdvancedSavingChanged() {
            if (!page.controller.advancedSaving && (page.securityDirty || page.hardwareDirty))
                autoSaveTimer.restart();
        }
    }

    component FieldLabel: Text {
        color: Theme.mutedText
        font.family: Theme.fontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    Flickable {
        id: securityFlick

        visible: page.securityView
        anchors.fill: parent
        contentWidth: width
        contentHeight: securityCards.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        clip: true

        Column {
            id: securityCards

            width: securityFlick.width
            spacing: page.sectionSpacing

            DetailCard {
                height: 178
                title: "Security"

                Column {
                    anchors.fill: parent
                    spacing: 10

                    DetailGrid {
                        width: parent.width
                        height: 44
                        entries: [{ label: "Security type", value: page.profile.security_type || "Unknown" }]
                    }

                    Column {
                        width: parent.width
                        height: 58
                        spacing: 5

                        FieldLabel { width: parent.width; height: 13; text: "Network password" }

                        Rectangle {
                            width: parent.width
                            height: 40
                            radius: Theme.controlRadius
                            color: Theme.input
                            border.width: 1
                            border.color: passwordInput.activeFocus ? Theme.strongBorder : Theme.border
                            opacity: page.personalSecurity ? 1.0 : 0.58

                            TextInput {
                                id: passwordInput

                                anchors.left: parent.left
                                anchors.right: passwordAction.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                leftPadding: 12
                                rightPadding: 10
                                readOnly: !page.personalSecurity
                                echoMode: page.passwordRevealed ? TextInput.Normal : TextInput.Password
                                text: page.passwordValue
                                color: Theme.inputText
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.accentText
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                verticalAlignment: TextInput.AlignVCenter
                                onTextEdited: {
                                    page.passwordValue = text;
                                    page.passwordDirty = true;
                                    page.queueSecuritySave();
                                }

                                Text {
                                    anchors.fill: parent
                                    leftPadding: 12
                                    verticalAlignment: Text.AlignVCenter
                                    visible: passwordInput.text.length === 0
                                    text: page.personalSecurity ? "Saved password" : "Unavailable for this security type"
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
                                        text: page.passwordRevealed ? "󰈉" : "󰈈"
                                        color: Theme.accent
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        text: page.controller.advancedSecretLoading ? "Loading" : (page.passwordRevealed ? "Hide" : "Show")
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                    }
                                }

                                MouseArea {
                                    id: passwordActionMouse

                                    anchors.fill: parent
                                    enabled: page.personalSecurity && !page.controller.advancedSecretLoading
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (page.passwordRevealed) page.passwordRevealed = false;
                                        else page.controller.revealAdvancedSecret();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            DetailCard {
                height: 158
                title: "Privacy"

                Column {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        width: parent.width
                        height: 40
                        spacing: 12

                        FieldLabel {
                            Layout.preferredWidth: 150
                            Layout.fillHeight: true
                            text: "Address policy"
                        }

                        AdvancedChoice {
                            Layout.fillWidth: true
                            value: page.macPolicy
                            options: [
                                { value: "default", label: "System default" },
                                { value: "stable", label: "Stable private address" },
                                { value: "random", label: "New random address each connection" },
                                { value: "permanent", label: "Permanent device address" }
                            ]
                            onSelected: function (value) {
                                page.macPolicy = value;
                                page.queueSecuritySave();
                            }
                        }
                    }

                    ProfileToggleRow {
                        width: parent.width
                        height: 44
                        title: "Device name sharing"
                        subtitle: "Share this device's hostname with the network"
                        checked: page.sendHostname
                        onClicked: {
                            page.sendHostname = !page.sendHostname;
                            page.queueSecuritySave();
                        }
                    }
                }
            }

            DetailCard {
                height: Math.max(120, securityFlick.height - 336 - 2 * securityCards.spacing)
                title: "Device identity"

                DetailGrid {
                    entries: [{
                        label: "Current device MAC",
                        value: ((page.status.wireless || {}).mac_address || "Unavailable")
                    }]
                }
            }
        }
    }

    Flickable {
        id: hardwareFlick

        visible: !page.securityView
        anchors.fill: parent
        contentWidth: width
        contentHeight: hardwareCards.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        clip: true

        Column {
            id: hardwareCards

            width: hardwareFlick.width
            spacing: page.sectionSpacing

            DetailCard {
                height: page.ipCardHeight
                title: "IP & DNS"

                Column {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        width: parent.width
                        height: 38
                        spacing: 12

                        FieldLabel {
                            Layout.preferredWidth: 150
                            Layout.fillHeight: true
                            text: "Address family"
                        }

                        AdvancedChoice {
                            Layout.fillWidth: true
                            value: page.ipFamily
                            options: [{ value: "ipv4", label: "IPv4" }, { value: "ipv6", label: "IPv6" }]
                            onSelected: function (value) { page.ipFamily = value; }
                        }
                    }

                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 8

                        FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "Assignment" }
                        AdvancedChoice {
                            Layout.fillWidth: true
                            value: page.currentMethod
                            options: [{ value: "auto", label: "Automatic" }, { value: "manual", label: "Manual" }, { value: "disabled", label: "Disabled" }]
                            onSelected: function (value) { page.setMethod(value); }
                        }

                        FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "DNS source" }
                        AdvancedChoice {
                            Layout.fillWidth: true
                            value: page.currentAutoDns ? "auto" : "manual"
                            options: [{ value: "auto", label: "Automatic" }, { value: "manual", label: "Manual" }]
                            onSelected: function (value) { page.setAutoDns(value); }
                        }

                        FieldLabel { visible: page.currentMethod === "manual"; Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "Address" }
                        AdvancedTextField {
                            visible: page.currentMethod === "manual"
                            Layout.fillWidth: true
                            text: page.ipFamily === "ipv4" ? page.ipv4Address : page.ipv6Address
                            placeholder: page.ipFamily === "ipv4" ? "192.168.1.20" : "2001:db8::20"
                            onEdited: function (value) {
                                if (page.ipFamily === "ipv4") page.ipv4Address = value;
                                else page.ipv6Address = value;
                                page.queueHardwareSave();
                            }
                        }

                        FieldLabel { visible: page.currentMethod === "manual"; Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "Prefix length" }
                        AdvancedTextField {
                            visible: page.currentMethod === "manual"
                            Layout.fillWidth: true
                            text: page.ipFamily === "ipv4" ? page.ipv4Prefix : page.ipv6Prefix
                            onEdited: function (value) {
                                if (page.ipFamily === "ipv4") page.ipv4Prefix = value;
                                else page.ipv6Prefix = value;
                                page.queueHardwareSave();
                            }
                        }

                        FieldLabel { visible: page.currentMethod === "manual"; Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "Gateway" }
                        AdvancedTextField {
                            visible: page.currentMethod === "manual"
                            Layout.fillWidth: true
                            text: page.ipFamily === "ipv4" ? page.ipv4Gateway : page.ipv6Gateway
                            onEdited: function (value) {
                                if (page.ipFamily === "ipv4") page.ipv4Gateway = value;
                                else page.ipv6Gateway = value;
                                page.queueHardwareSave();
                            }
                        }

                        FieldLabel { visible: !page.currentAutoDns; Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "DNS servers" }
                        AdvancedTextField {
                            visible: !page.currentAutoDns
                            Layout.fillWidth: true
                            text: page.ipFamily === "ipv4" ? page.ipv4Dns : page.ipv6Dns
                            placeholder: "Comma-separated addresses"
                            onEdited: function (value) {
                                if (page.ipFamily === "ipv4") page.ipv4Dns = value;
                                else page.ipv6Dns = value;
                                page.queueHardwareSave();
                            }
                        }

                        FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "DNS search domains" }
                        AdvancedTextField {
                            Layout.fillWidth: true
                            text: page.ipFamily === "ipv4" ? page.ipv4Search : page.ipv6Search
                            placeholder: "Optional, comma-separated"
                            onEdited: function (value) {
                                if (page.ipFamily === "ipv4") page.ipv4Search = value;
                                else page.ipv6Search = value;
                                page.queueHardwareSave();
                            }
                        }
                    }
                }
            }

            DetailCard {
                height: 190
                title: "Adapter & radio"

                DetailGrid {
                    entries: [
                        { label: "Interface", value: page.ap.device_iface || page.status.device_iface || "—" },
                        { label: "Mode", value: page.ap.mode ? "Wi-Fi " + page.ap.mode : "Infrastructure" },
                        { label: "Band / frequency", value: (page.ap.band || "—") + " / " + (page.ap.frequency || "—") + " MHz" },
                        { label: "Channel", value: page.ap.channel === undefined ? "—" : String(page.ap.channel) },
                        { label: "Maximum bitrate", value: page.ap.max_bitrate_mbps ? page.ap.max_bitrate_mbps + " Mbps" : "—" }
                    ]
                }
            }

            DetailCard {
                height: Math.max(145, hardwareFlick.height - page.ipCardHeight - 190 - 2 * hardwareCards.spacing)
                title: "Identifiers"

                DetailGrid {
                    entries: [
                        { label: "BSSID", value: page.ap.bssid || "—" },
                        { label: "Device MAC", value: ((page.status.wireless || {}).mac_address || "—") },
                        { label: "Profile path", value: page.profile.path || "—" }
                    ]
                }
            }
        }
    }

    Rectangle {
        visible: page.controller.advancedError.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: Math.min(parent.width - 24, errorText.implicitWidth + 24)
        height: 34
        radius: Theme.controlRadius
        color: Theme.dangerBackground
        border.width: 1
        border.color: Theme.danger

        Text {
            id: errorText
            anchors.centerIn: parent
            text: page.controller.advancedError
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    CenteredMessage {
        visible: page.controller.advancedLoading
        text: "Loading saved profile…"
    }
}
