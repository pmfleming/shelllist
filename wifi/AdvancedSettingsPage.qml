pragma ComponentBehavior: Bound

import QtQuick
import "."
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
    property string ipFamily: "ipv4"
    property bool hardwareDirty

    readonly property bool hasDirtyChanges: securityDirty || hardwareDirty
    readonly property bool securityView: controller.advanced.section === "security"
    property real sectionOffset
    readonly property bool personalSecurity: String(profile.security_type || "").indexOf("Personal") >= 0
    readonly property IpSettingsState currentIp: ipFamily === "ipv4" ? ipv4State : ipv6State
    readonly property string currentMethod: currentIp.method
    readonly property bool currentAutoDns: currentIp.autoDns
    readonly property bool currentFamilyEnabled: currentMethod !== "disabled"
    readonly property var ap: controller.detailAp
    readonly property var status: controller.activeStatus || ({})
    readonly property var bandStatus: controller.bandStatus || ({})
    readonly property var dhcpLease: controller.isActive(ap)
        ? (((status.ip4 || {}).dhcp_lease) || ({}))
        : ({})
    readonly property var currentActiveIp: controller.isActive(ap)
        ? (status[ipFamily === "ipv4" ? "ip4" : "ip6"] || ({}))
        : ({})
    readonly property string displayedAddress: currentMethod === "auto" && currentActiveIp.address
        ? String(currentActiveIp.address)
        : currentIp.address
    readonly property string displayedPrefix: currentMethod === "auto"
            && currentActiveIp.prefix !== undefined && currentActiveIp.prefix !== null
        ? String(currentActiveIp.prefix)
        : currentIp.prefix
    readonly property string displayedGateway: currentMethod === "auto" && currentActiveIp.gateway
        ? String(currentActiveIp.gateway)
        : currentIp.gateway
    readonly property string displayedDns: currentAutoDns && currentActiveIp.dns && currentActiveIp.dns.length > 0
        ? currentActiveIp.dns.join(", ")
        : currentIp.dns

    clip: true
    focus: visible && controller.advanced.open
    Keys.onEscapePressed: controller.advanced.closeSettings()

    function showSection(nextSection: string, animate: bool): void {
        sectionTransition.stop();
        if (!animate || Theme.noAnimations) {
            sectionOffset = 0;
            return;
        }
        sectionOffset = nextSection === "security" ? -width : width;
        sectionTransition.start();
    }

    NumberAnimation {
        id: sectionTransition
        target: page
        property: "sectionOffset"
        to: 0
        duration: Theme.animationInteractive
        easing.type: Theme.easingResponsive
    }

    function resetEditState(): void {
        autoSaveTimer.stop();
        passwordValue = "";
        passwordDirty = false;
        passwordRevealed = false;
        securityDirty = false;
        hardwareDirty = false;
    }

    function syncProfile(): void {
        resetEditState();
        if (!profile || !profile.path)
            return;
        macPolicy = profile.mac_address_policy || "default";
        sendHostname = profile.send_hostname !== false;
        ipv4State.sync(profile.ipv4);
        ipv6State.sync(profile.ipv6);
    }

    function queueSecuritySave(): void {
        securityDirty = true;
        autoSaveTimer.restart();
    }

    function setBand(value: string): void {
        if (!profile.path || value === (bandStatus.selected || "auto"))
            return;
        controller.setBand(profile.path, value);
    }

    function setMacPolicy(value: string): void {
        if (macPolicy === value)
            return;
        macPolicy = value;
        queueSecuritySave();
    }

    function queueHardwareSave(): void {
        hardwareDirty = true;
        autoSaveTimer.restart();
    }

    function hardwareSettingsReady(): bool { return ipv4State.ready() && ipv6State.ready(); }

    function saveOrigin(): string {
        if (securityDirty === hardwareDirty)
            return controller.advanced.section;
        return securityDirty ? "security" : "hardware";
    }

    function settingsPayload(): var {
        return {
            autoconnect: !!profile.autoconnect,
            metered: profile.metered || "auto",
            hidden: !!profile.hidden,
            mac_address_policy: macPolicy,
            send_hostname: sendHostname,
            ipv4: ipv4State.payload(profile.ipv4),
            ipv6: ipv6State.payload(profile.ipv6),
            password: passwordDirty && passwordValue.length > 0 ? passwordValue : null
        };
    }

    function saveReady(): bool {
        if (!hasDirtyChanges || !profile.path)
            return false;
        if (controller.advanced.saving || controller.advanced.loading) {
            autoSaveTimer.restart();
            return false;
        }
        // Selecting Manual reveals an initially empty form. Keep the edit local until the
        // required address has been entered instead of sending a predictably invalid update.
        if (hardwareDirty && !hardwareSettingsReady()) {
            controller.advanced.error = "";
            return false;
        }
        return true;
    }

    function saveDirty(): void {
        if (!saveReady())
            return;
        if (!controller.advanced.save(settingsPayload(), saveOrigin())) {
            autoSaveTimer.restart();
            return;
        }
        securityDirty = false;
        hardwareDirty = false;
        passwordDirty = false;
    }

    function setMethod(value: string): void {
        if (value === currentMethod)
            return;
        currentIp.method = value;
        queueHardwareSave();
    }

    function setAutoDns(value: bool): void {
        const automatic = !!value;
        if (automatic === currentAutoDns)
            return;
        currentIp.setAutoDns(automatic);
        queueHardwareSave();
    }

    IpSettingsState { id: ipv4State; family: "ipv4"; fallbackPrefix: 24 }
    IpSettingsState { id: ipv6State; family: "ipv6"; fallbackPrefix: 64 }

    Component.onCompleted: syncProfile()
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

        function onSectionTransitionRequested(section, animate) {
            page.showSection(section, animate);
        }

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

    Loader {
        width: parent.width
        height: parent.height
        x: page.sectionOffset
        active: true
        sourceComponent: page.securityView ? securitySection : ipSection
    }

    Component {
        id: securitySection
        AdvancedSecurityPane { settings: page }
    }

    Component {
        id: ipSection
        AdvancedIpSettingsPane { settings: page }
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
