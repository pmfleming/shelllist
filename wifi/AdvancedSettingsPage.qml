pragma ComponentBehavior: Bound

import QtQuick
import "."
import "networkinput" as NetworkInput
import Shelllist.Ui

Item {
    id: page

    required property WifiController controller

    property var profile: controller.advanced.profile
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

    readonly property bool securityView: controller.advanced.section === "security"
    property real sectionTransitionProgress: securityView ? 0 : 1
    readonly property bool personalSecurity: String(profile.security_type || "").indexOf("Personal") >= 0
    readonly property string currentMethod: ipFamily === "ipv4" ? ipv4Method : ipv6Method
    readonly property bool currentAutoDns: ipFamily === "ipv4" ? ipv4AutoDns : ipv6AutoDns
    readonly property bool currentFamilyEnabled: currentMethod !== "disabled"
    readonly property var ap: controller.detailAp
    readonly property var status: controller.activeStatus || ({})
    readonly property var dhcpLease: controller.isActive(ap)
        ? (((status.ip4 || {}).dhcp_lease) || ({}))
        : ({})
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
    focus: visible && controller.advanced.open
    Keys.onEscapePressed: controller.advanced.closeSettings()

    Behavior on sectionTransitionProgress {
        // Entering the advanced area already has its own page transition. Only animate
        // this track when moving between its two tabs, so no stale pane slides away
        // while the details chooser itself is opening.
        enabled: !Theme.noAnimations && page.controller.advanced.open
        NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
    }

    function firstAddress(settings) {
        return settings && settings.addresses && settings.addresses.length > 0 ? settings.addresses[0] : ({});
    }

    function leaseDurationLabel(seconds) {
        const total = Math.max(0, Number(seconds) || 0);
        if (total === 0)
            return "—";
        const days = Math.floor(total / 86400);
        const hours = Math.floor((total % 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        if (days > 0)
            return days + "d" + (hours > 0 ? " " + hours + "h" : "");
        if (hours > 0)
            return hours + "h" + (minutes > 0 ? " " + minutes + "m" : "");
        return Math.max(1, minutes) + "m";
    }

    function leaseExpiryLabel(milliseconds) {
        const value = Number(milliseconds) || 0;
        return value > 0 ? Qt.formatDateTime(new Date(value), "d MMM yyyy, HH:mm") : "—";
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

    function setMacPolicy(value) {
        if (macPolicy === value)
            return;
        macPolicy = value;
        queueSecuritySave();
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

    function saveOrigin() {
        if (securityDirty === hardwareDirty)
            return controller.advanced.section;
        return securityDirty ? "security" : "hardware";
    }

    function settingsPayload() {
        return {
            autoconnect: !!profile.autoconnect,
            metered: profile.metered || "auto",
            hidden: !!profile.hidden,
            mac_address_policy: macPolicy,
            send_hostname: sendHostname,
            ipv4: buildIp("ipv4", profile.ipv4 || ({})),
            ipv6: buildIp("ipv6", profile.ipv6 || ({})),
            password: passwordDirty && passwordValue.length > 0 ? passwordValue : null
        };
    }

    function saveDirty() {
        if ((!securityDirty && !hardwareDirty) || !profile.path)
            return;
        if (controller.advanced.saving || controller.advanced.loading)
            return autoSaveTimer.restart();
        // Selecting Manual reveals an initially empty form. Keep the edit local until the
        // required address has been entered instead of sending a predictably invalid update.
        if (hardwareDirty && !hardwareSettingsReady()) {
            controller.advanced.error = "";
            return;
        }
        if (!controller.advanced.save(settingsPayload(), saveOrigin()))
            return autoSaveTimer.restart();
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
        target: page.controller.advanced

        function onSecretChanged() {
            if (page.controller.advanced.secret.length === 0)
                return;
            page.passwordValue = page.controller.advanced.secret;
            page.passwordDirty = false;
            page.passwordRevealed = true;
        }

        function onSavingChanged() {
            if (!page.controller.advanced.saving && (page.securityDirty || page.hardwareDirty))
                autoSaveTimer.restart();
        }
    }

    Connections {
        target: page.controller
        function onAdvancedSectionLeaving() {
            autoSaveTimer.stop();
            page.saveDirty();
        }
    }

    AdvancedSecurityPane {
        width: parent.width
        height: parent.height
        x: -width * page.sectionTransitionProgress
        enabled: page.securityView
        settings: page
    }

    AdvancedIpSettingsPane {
        width: parent.width
        height: parent.height
        x: width * (1 - page.sectionTransitionProgress)
        enabled: !page.securityView
        settings: page
    }

    Rectangle {
        visible: page.controller.advanced.error.length > 0
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
            text: page.controller.advanced.error
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    CenteredMessage {
        visible: page.controller.advanced.loading
        text: "Loading saved profile…"
    }
}
