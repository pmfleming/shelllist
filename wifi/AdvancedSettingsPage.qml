pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."
import "networkinput" as NetworkInput

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
    readonly property bool currentFamilyEnabled: currentMethod !== "disabled"
    readonly property var ap: controller.detailAp
    readonly property var status: controller.activeStatus || ({})
    readonly property var currentActiveIp: controller.isActive(ap)
        ? (status[ipFamily === "ipv4" ? "ip4" : "ip6"] || ({}))
        : ({})
    readonly property string displayedAddress: currentMethod === "auto" && currentActiveIp.address
        ? String(currentActiveIp.address)
        : ipValue(ipFamily, "Address")
    readonly property string displayedPrefix: currentMethod === "auto"
            && currentActiveIp.prefix !== undefined && currentActiveIp.prefix !== null
        ? String(currentActiveIp.prefix)
        : ipValue(ipFamily, "Prefix")
    readonly property string displayedGateway: currentMethod === "auto" && currentActiveIp.gateway
        ? String(currentActiveIp.gateway)
        : ipValue(ipFamily, "Gateway")
    readonly property string displayedDns: currentAutoDns && currentActiveIp.dns && currentActiveIp.dns.length > 0
        ? currentActiveIp.dns.join(", ")
        : ipValue(ipFamily, "Dns")

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

    function ipSettingsReady(family) {
        const method = ipValue(family, "Method");
        if (method === "manual") {
            if (!NetworkInput.IpValidator.isAddressInput(ipValue(family, "Address"), family, false, false))
                return false;
            if (!NetworkInput.IpValidator.isPrefix(ipValue(family, "Prefix"), family, false))
                return false;
        }
        if (!NetworkInput.IpValidator.isAddressInput(ipValue(family, "Gateway"), family, false, true))
            return false;
        return ipValue(family, "AutoDns")
            || NetworkInput.IpValidator.isAddressInput(ipValue(family, "Dns"), family, true, true);
    }

    function hardwareSettingsReady() {
        return ipSettingsReady("ipv4") && ipSettingsReady("ipv6");
    }

    function saveDirty() {
        if ((!securityDirty && !hardwareDirty) || !profile.path)
            return;
        if (controller.advancedSaving || controller.advancedLoading) {
            autoSaveTimer.restart();
            return;
        }
        // Selecting Manual reveals an initially empty form. Keep the edit local until the
        // required address has been entered instead of sending a predictably invalid update.
        if (hardwareDirty && !hardwareSettingsReady()) {
            controller.advancedError = "";
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
                height: 245
                title: "Device"

                DetailGrid {
                    entries: [
                        { label: "BSSID", value: page.ap.bssid || "—" },
                        { label: "Device MAC", value: ((page.status.wireless || {}).mac_address || "—") },
                        { label: "Profile path", value: page.profile.path || "—" },
                        { label: "Interface", value: page.ap.device_iface || page.status.device_iface || "—" },
                        { label: "Mode", value: page.ap.mode ? "Wi-Fi " + page.ap.mode : "Infrastructure" },
                        { label: "Band / frequency", value: (page.ap.band || "—") + " / " + (page.ap.frequency || "—") + " MHz" },
                        { label: "Channel", value: page.ap.channel === undefined ? "—" : String(page.ap.channel) },
                        { label: "Maximum bitrate", value: page.ap.max_bitrate_mbps ? page.ap.max_bitrate_mbps + " Mbps" : "—" }
                    ]
                }
            }

            DetailCard {
                height: 122
                title: "Security"

                Column {
                    anchors.fill: parent

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
                height: Math.max(158, securityFlick.height - 367 - 2 * securityCards.spacing)
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
                height: Math.max(500, hardwareFlick.height)
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

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            ActionButton {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                label: "IPv4"
                                backgroundColor: page.ipFamily === "ipv4" ? Theme.selected : Theme.input
                                borderColor: page.ipFamily === "ipv4" ? Theme.accent : Theme.border
                                labelColor: page.ipFamily === "ipv4" ? Theme.accent : Theme.text
                                onClicked: page.ipFamily = "ipv4"
                            }

                            ActionButton {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                label: "IPv6"
                                backgroundColor: page.ipFamily === "ipv6" ? Theme.selected : Theme.input
                                borderColor: page.ipFamily === "ipv6" ? Theme.accent : Theme.border
                                labelColor: page.ipFamily === "ipv6" ? Theme.accent : Theme.text
                                onClicked: page.ipFamily = "ipv6"
                            }
                        }
                    }

                    ProfileToggleRow {
                        width: parent.width
                        height: 44
                        title: page.ipFamily === "ipv4" ? "Enable IPv4" : "Enable IPv6"
                        showSubtitle: false
                        checked: page.currentFamilyEnabled
                        onClicked: page.setMethod(page.currentFamilyEnabled ? "disabled" : "auto")
                    }

                    ProfileToggleRow {
                        width: parent.width
                        height: 44
                        title: "Automatic addressing"
                        showSubtitle: false
                        checked: page.currentMethod === "auto"
                        interactive: page.currentFamilyEnabled
                        onClicked: page.setMethod(page.currentMethod === "auto" ? "manual" : "auto")
                    }

                    ProfileToggleRow {
                        width: parent.width
                        height: 44
                        title: "Automatic DNS"
                        showSubtitle: false
                        checked: page.currentAutoDns
                        interactive: page.currentFamilyEnabled
                        onClicked: page.setAutoDns(!page.currentAutoDns)
                    }

                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 8

                        FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "IP address" }
                        NetworkInput.IpAddressField {
                            Layout.fillWidth: true
                            family: page.ipFamily
                            allowEmpty: page.currentMethod !== "manual"
                            readOnly: page.currentMethod !== "manual"
                            text: page.displayedAddress
                            onEdited: function (value) {
                                if (page.ipFamily === "ipv4") page.ipv4Address = value;
                                else page.ipv6Address = value;
                            }
                            onEditingFinished: page.queueHardwareSave()
                        }

                        FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "Prefix length" }
                        NetworkInput.PrefixLengthField {
                            Layout.fillWidth: true
                            family: page.ipFamily
                            allowEmpty: page.currentMethod !== "manual"
                            readOnly: page.currentMethod !== "manual"
                            text: page.displayedPrefix
                            onEdited: function (value) {
                                if (page.ipFamily === "ipv4") page.ipv4Prefix = value;
                                else page.ipv6Prefix = value;
                            }
                            onEditingFinished: page.queueHardwareSave()
                        }

                        FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "Gateway" }
                        NetworkInput.IpAddressField {
                            Layout.fillWidth: true
                            family: page.ipFamily
                            readOnly: page.currentMethod !== "manual"
                            text: page.displayedGateway
                            onEdited: function (value) {
                                if (page.ipFamily === "ipv4") page.ipv4Gateway = value;
                                else page.ipv6Gateway = value;
                            }
                            onEditingFinished: page.queueHardwareSave()
                        }

                        FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "DNS servers" }
                        NetworkInput.IpAddressField {
                            Layout.fillWidth: true
                            family: page.ipFamily
                            multiple: true
                            readOnly: !page.currentFamilyEnabled || page.currentAutoDns
                            text: page.displayedDns
                            onEdited: function (value) {
                                if (page.ipFamily === "ipv4") page.ipv4Dns = value;
                                else page.ipv6Dns = value;
                            }
                            onEditingFinished: page.queueHardwareSave()
                        }

                        FieldLabel { Layout.preferredWidth: 150; Layout.preferredHeight: 38; text: "DNS search domains" }
                        AdvancedTextField {
                            Layout.fillWidth: true
                            readOnly: !page.currentFamilyEnabled
                            text: page.ipFamily === "ipv4" ? page.ipv4Search : page.ipv6Search
                            placeholder: "Optional, comma-separated"
                            onEdited: function (value) {
                                if (page.ipFamily === "ipv4") page.ipv4Search = value;
                                else page.ipv6Search = value;
                            }
                            onEditingFinished: page.queueHardwareSave()
                        }
                    }
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
