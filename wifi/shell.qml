import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "."

ShellRoot {
    id: root

    property var networks: []
    property var activeStatus: null
    property string filterText: ""
    property int selectedIndex: 0
    property bool pendingRefresh: false
    property string status: "Loading Wi-Fi networks…"
    property string lastConnectedSsid: ""
    property bool scanSnapshotSeen: false
    property bool promptOpen: false
    property string promptMode: ""
    property string promptTitle: ""
    property string promptDetail: ""
    property string promptText: ""
    property bool promptPassword: false
    property var promptNetwork: null
    property string pendingHiddenSsid: ""
    property bool pendingConnectUsesStdin: false
    property string pendingConnectPassword: ""
    property string pendingEnterpriseIdentity: ""

    readonly property bool actionInFlight: connectProc.running || disconnectProc.running || profileProc.running
    readonly property var filteredNetworks: networks.filter(function (ap) {
        return !root.filterText || (ap.ssid || "").toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1;
    })
    readonly property var detailAp: selectedNetwork() || ({})
    readonly property bool hasSelection: filteredNetworks.length > 0

    function clampIndex(index, length) {
        return length <= 0 ? 0 : Math.max(0, Math.min(index, length - 1));
    }

    function selectedNetwork() {
        if (filteredNetworks.length === 0)
            return null;
        return filteredNetworks[clampIndex(selectedIndex, filteredNetworks.length)];
    }

    function networkName(ap) {
        return ap && ap.ssid ? ap.ssid : "<hidden>";
    }

    function securityLabel(security) {
        return security === "--" ? "Open" : (security || "Unknown");
    }

    function hasNetworkIdentity(ap) {
        return !!(ap && ((ap.ssid_bytes && ap.ssid_bytes.length > 0) || (ap.ssid && ap.ssid.length > 0)));
    }

    function canConnect(ap) {
        if (!ap)
            return false;
        if (ap.capabilities)
            return ap.capabilities.can_connect;
        return hasNetworkIdentity(ap);
    }

    function needsPassword(ap) {
        return !!(ap && hasNetworkIdentity(ap) && ap.capabilities && ap.capabilities.needs_password);
    }

    function needsCredentials(ap) {
        return !!(ap && hasNetworkIdentity(ap) && ap.capabilities && ap.capabilities.needs_credentials);
    }

    function canStartConnection(ap) {
        return canConnect(ap) || needsPassword(ap) || needsCredentials(ap);
    }

    function accessPointPath(ap) {
        return ap ? (ap.path || ap.ap_path || "") : "";
    }

    function hasSsidIdentity(ap) {
        return !!(ap && ((ap.ssid_bytes && ap.ssid_bytes.length > 0) || (ap.ssid && ap.ssid.length > 0)));
    }

    function sameAccessPoint(left, right) {
        if (!left || !right)
            return false;

        const leftPath = accessPointPath(left);
        const rightPath = accessPointPath(right);
        if (leftPath && rightPath)
            return leftPath === rightPath;

        if (left.bssid && right.bssid)
            return left.bssid === right.bssid;

        if (!hasSsidIdentity(left) || !hasSsidIdentity(right))
            return false;

        return (left.ssid || "") === (right.ssid || "") && (left.security || "") === (right.security || "");
    }

    function activeAccessPoint() {
        if (!activeStatus)
            return null;
        return activeStatus.access_point || (activeStatus.network || null);
    }

    function isActive(ap) {
        const active = activeAccessPoint();
        return !!(ap && (ap.active || sameAccessPoint(ap, active)));
    }

    function profileFor(ap) {
        if (!ap)
            return null;
        if (ap.primary_profile)
            return ap.primary_profile;
        if (ap.profiles && ap.profiles.length > 0)
            return ap.profiles[0];
        if (isActive(ap) && activeStatus && activeStatus.profile)
            return activeStatus.profile;
        return null;
    }

    function frequencyLabel(ap) {
        const frequency = ap && ap.frequency ? ap.frequency : 0;
        if (frequency <= 0)
            return "Unknown";
        const band = frequency >= 5925 ? "6 GHz" : frequency >= 4900 ? "5 GHz" : "2.4 GHz";
        return band + " (" + frequency + " MHz)";
    }

    function wifiType(ap) {
        const frequency = ap && ap.frequency ? ap.frequency : 0;
        if (frequency >= 5925)
            return "Wi-Fi 6E/7";
        if (frequency >= 4900)
            return "Wi-Fi 5/6";
        if (frequency > 0)
            return "Wi-Fi 4/6";
        return "Unknown";
    }

    function subnetLabel(ip4) {
        if (!ip4)
            return "—";
        if (ip4.prefix !== null && ip4.prefix !== undefined)
            return "/" + ip4.prefix;
        return "—";
    }

    function dnsLabel(ip4) {
        if (!ip4 || !ip4.dns || ip4.dns.length === 0)
            return "—";
        return ip4.dns.join(", ");
    }

    function networkUsageLabel() {
        const metered = activeStatus && activeStatus.metered ? activeStatus.metered : null;
        if (!metered)
            return "—";
        if (metered.state === "yes")
            return "Metered";
        if (metered.state === "no")
            return "Unmetered";
        if (metered.state === "guess-yes")
            return "Probably metered";
        if (metered.state === "guess-no")
            return "Probably unmetered";
        return "Unknown";
    }

    function lastSeenLabel(ap) {
        if (!ap || ap.last_seen < 0)
            return "";
        if (!hasNumber(ap.last_seen_age_ms))
            return "Last seen: scan result available";
        const seconds = Math.max(0, Math.round(ap.last_seen_age_ms / 1000));
        if (seconds < 5)
            return "Last seen: just now";
        if (seconds < 60)
            return "Last seen: " + seconds + "s ago";
        const minutes = Math.round(seconds / 60);
        if (minutes < 60)
            return "Last seen: " + minutes + "m ago";
        const hours = Math.round(minutes / 60);
        return "Last seen: " + hours + "h ago";
    }

    function hasNumber(value) {
        return value !== null && value !== undefined && !isNaN(value);
    }

    function formatMbps(value) {
        if (!hasNumber(value))
            return "—";
        const rounded = Math.round(value * 10) / 10;
        return (Math.abs(rounded - Math.round(rounded)) < 0.01 ? Math.round(rounded) : rounded) + " Mbps";
    }

    function wirelessStatus() {
        return activeStatus && activeStatus.wireless ? activeStatus.wireless : null;
    }

    function hasDirectionalBitrates() {
        const wireless = wirelessStatus();
        return !!(wireless && (hasNumber(wireless.tx_bitrate_mbps) || hasNumber(wireless.rx_bitrate_mbps)));
    }

    function bitrateLabel() {
        const wireless = wirelessStatus();
        return wireless ? formatMbps(wireless.bitrate_mbps) : "—";
    }

    function txBitrateLabel() {
        const wireless = wirelessStatus();
        return wireless ? formatMbps(wireless.tx_bitrate_mbps) : "—";
    }

    function rxBitrateLabel() {
        const wireless = wirelessStatus();
        return wireless ? formatMbps(wireless.rx_bitrate_mbps) : "—";
    }

    function macLabel() {
        const wireless = wirelessStatus();
        return wireless && wireless.mac_address ? wireless.mac_address : "—";
    }

    function activeIp4Value(field) {
        const ip4 = activeStatus && activeStatus.ip4 ? activeStatus.ip4 : null;
        return isActive(detailAp) && ip4 && ip4[field] ? ip4[field] : "—";
    }

    function activeDetailValue(value) {
        return isActive(detailAp) ? value : "—";
    }

    function autoconnectEnabled() {
        const profile = profileFor(detailAp);
        return !!(profile && profile.autoconnect);
    }

    function privacyFor(ap) {
        const profile = profileFor(ap);
        return profile && profile.privacy ? profile.privacy : ({});
    }

    function randomizedMacEnabled() {
        return !!privacyFor(detailAp).randomized_mac;
    }

    function sendHostnameEnabled() {
        const privacy = privacyFor(detailAp);
        return privacy.send_hostname !== false;
    }

    function canEditProfile() {
        return !actionInFlight && !!profileFor(detailAp);
    }

    function canUsePrimaryAction() {
        return !actionInFlight && (isActive(detailAp) || canStartConnection(detailAp));
    }

    function applyNetworks(newNetworks, resetSelection) {
        const previous = selectedNetwork();
        networks = newNetworks;

        if (resetSelection || !previous) {
            const activeIndex = filteredNetworks.findIndex(function (ap) {
                return root.isActive(ap);
            });
            selectedIndex = activeIndex >= 0 ? activeIndex : 0;
        } else {
            const nextIndex = filteredNetworks.findIndex(function (ap) {
                return sameAccessPoint(previous, ap);
            });
            selectedIndex = nextIndex >= 0 ? nextIndex : clampIndex(selectedIndex, filteredNetworks.length);
        }
    }

    function refresh() {
        if (listProc.running || scanStreamProc.running) {
            pendingRefresh = true;
            status = "Refresh already running; queued another refresh…";
            refreshStatus();
            return;
        }

        pendingRefresh = false;
        status = "Loading cached Wi-Fi networks…";
        scanSnapshotSeen = false;
        listProc.exec(["nm-wifi", "networks", "--cached", "--json"]);
        refreshStatus();
        startScanStream();
    }

    function maybeRunPendingRefresh() {
        if (pendingRefresh && !listProc.running && !scanStreamProc.running)
            Qt.callLater(refresh);
    }

    function refreshStatus() {
        if (!statusProc.running)
            statusProc.exec(["nm-wifi", "status", "--json"]);
    }

    function startScanStream() {
        if (!scanStreamProc.running)
            scanStreamProc.exec(["nm-wifi", "scan", "--stream", "--cache", "--timeout", "12"]);
    }

    function handleScanEvent(line) {
        const trimmed = line.trim();
        if (!trimmed)
            return;

        try {
            const event = JSON.parse(trimmed);
            const handlers = {
                snapshot: function (e) {
                    scanSnapshotSeen = true;
                    applyNetworks(e.networks || [], false);
                    status = e.networks_found + (e.scanning ? " networks found; scanning…" : " networks available");
                },
                status: function (e) {
                    status = e.message || status;
                },
                warning: function (e) {
                    status = e.message || status;
                },
                complete: function (e) {
                    status = e.networks_found + (e.timed_out ? " networks available; scan timed out" : " networks available");
                    refreshStatus();
                }
            };
            if (handlers[event.event])
                handlers[event.event](event);
        } catch (error) {
            status = "Could not parse scan event: " + error;
        }
    }

    function beginAction() {
        if (!actionInFlight)
            return true;
        status = "Wait for the current Wi-Fi action to finish…";
        return false;
    }

    function connectSelected() {
        if (!beginAction())
            return;

        const ap = selectedNetwork();
        if (!ap)
            return;
        if (needsPassword(ap)) {
            openPasswordPrompt(ap);
            return;
        }
        if (needsCredentials(ap)) {
            openEnterpriseIdentityPrompt(ap);
            return;
        }
        if (!canConnect(ap)) {
            status = "This access point cannot be connected from Shelllist yet. Use F6 for hidden SSIDs.";
            return;
        }

        runConnect(["nm-wifi", "connect-target", JSON.stringify(ap), "--json"], networkName(ap));
    }

    function runConnect(args, displayName, password) {
        if (!beginAction())
            return;

        pendingConnectUsesStdin = password !== undefined && password !== null;
        pendingConnectPassword = pendingConnectUsesStdin ? password : "";
        const commandArgs = args.slice();
        if (pendingConnectUsesStdin)
            commandArgs.push("--password-stdin");

        status = "Connecting to " + displayName + "…";
        lastConnectedSsid = displayName;
        connectProc.stdinEnabled = pendingConnectUsesStdin;
        connectProc.exec(commandArgs);
    }

    function connectFailureMessage(result, fallbackText) {
        const reasonLabels = {
            "secret-required": "Password required",
            "authorization-required": "Authorization required",
            "unsupported-auth": "Unsupported Wi-Fi authentication",
            "validation-error": "Invalid Wi-Fi target",
            "timeout": "Connection timed out",
            "activation-failed": "Connection activation failed",
            "unknown": "Connect failed"
        };
        const label = reasonLabels[result.reason || "unknown"] || "Connect failed";
        const detail = result.message || fallbackText || "unknown error";
        return label + ": " + detail;
    }

    function applyConnectResult(result) {
        const connectivity = result.connectivity || {};
        if (result.status === "error") {
            status = connectFailureMessage(result, connectErr.text);
            return;
        }
        if (result.suggest_open_portal) {
            status = result.message + "; opening captive portal…";
            openPortal();
        } else if (connectivity.state === "full") {
            status = "Connected to " + result.ssid + " with full connectivity";
        } else if (connectivity.state) {
            status = "Connected to " + result.ssid + "; connectivity: " + connectivity.state;
        } else {
            status = result.message;
        }
    }

    function disconnectSelected() {
        if (!beginAction())
            return;

        status = "Disconnecting Wi-Fi…";
        disconnectProc.exec(["nm-wifi", "disconnect", "--json"]);
    }

    function runProfileAction(action) {
        if (!beginAction())
            return;

        const profile = profileFor(selectedNetwork());
        if (profile)
            action(profile);
    }

    function forgetSelected() {
        runProfileAction(function (profile) {
            status = "Forgetting saved profile " + profile.id + "…";
            profileProc.exec(["nm-wifi", "profile", "delete", profile.path]);
        });
    }

    function toggleAutoconnectSelected() {
        runProfileAction(function (profile) {
            const enabled = !profile.autoconnect;
            status = (enabled ? "Enabling" : "Disabling") + " autoconnect for " + profile.id + "…";
            profileProc.exec(["nm-wifi", "profile", "autoconnect", profile.path, enabled ? "true" : "false"]);
        });
    }

    function setMacRandomizedSelected(enabled) {
        runProfileAction(function (profile) {
            status = (enabled ? "Using randomized MAC for " : "Using device MAC for ") + profile.id + "…";
            profileProc.exec(["nm-wifi", "profile", "mac-randomization", profile.path, enabled ? "true" : "false"]);
        });
    }

    function toggleSendHostnameSelected() {
        runProfileAction(function (profile) {
            const enabled = !(profile.privacy && profile.privacy.send_hostname !== false);
            status = (enabled ? "Sending" : "Hiding") + " device name for " + profile.id + "…";
            profileProc.exec(["nm-wifi", "profile", "send-hostname", profile.path, enabled ? "true" : "false"]);
        });
    }

    function openPortal() {
        status = "Opening captive portal pages…";
        portalProc.exec(["shelllist-captive-portal"]);
    }

    function openPrompt(mode, title, detail, password, network, hiddenSsid) {
        promptNetwork = network || null;
        pendingHiddenSsid = hiddenSsid || "";
        promptMode = mode;
        promptTitle = title;
        promptDetail = detail;
        promptText = "";
        promptPassword = password;
        promptOpen = true;
    }

    function openPasswordPrompt(ap) {
        openPrompt("network-password", "Password for " + networkName(ap), "Enter the Wi-Fi password, then press Enter.", true, ap, "");
    }

    function openHiddenNetworkPrompt() {
        openPrompt("hidden-ssid", "Connect hidden network", "Enter the hidden SSID, then press Enter.", false, null, "");
    }

    function openHiddenPasswordPrompt(ssid) {
        openPrompt("hidden-password", "Password for hidden network", "Enter the password for " + ssid + ", or leave blank for an open network.", true, null, ssid);
    }

    function cancelPrompt() {
        promptOpen = false;
        promptText = "";
        promptMode = "";
        promptNetwork = null;
        pendingHiddenSsid = "";
        pendingEnterpriseIdentity = "";
    }

    function openEnterpriseIdentityPrompt(ap) {
        const auth = ap && ap.auth ? ap.auth : ({});
        const detail = auth.note || "Enter your enterprise Wi-Fi identity. Shelllist will use PEAP/MSCHAPv2 defaults for now.";
        openPrompt("enterprise-identity", "Enterprise identity for " + networkName(ap), detail, false, ap, "");
    }

    function openEnterprisePasswordPrompt(ap, identity) {
        pendingEnterpriseIdentity = identity;
        openPrompt("enterprise-password", "Enterprise password for " + identity, "Enter your enterprise Wi-Fi password, then press Enter.", true, ap, "");
    }

    function enterpriseTarget(ap, identity) {
        const target = JSON.parse(JSON.stringify(ap));
        target.enterprise = {
            eap: ["peap"],
            identity: identity,
            phase2_auth: "mschapv2"
        };
        return target;
    }

    function submitNetworkPasswordPrompt(value) {
        if (value.length === 0) {
            status = "Enter a password for this network.";
            return;
        }

        const ap = promptNetwork;
        cancelPrompt();
        if (ap)
            runConnect(["nm-wifi", "connect-target", JSON.stringify(ap), "--json"], networkName(ap), value);
    }

    function submitHiddenSsidPrompt(value) {
        if (value.length === 0) {
            status = "Enter an SSID for the hidden network.";
            return;
        }
        openHiddenPasswordPrompt(value);
    }

    function submitHiddenPasswordPrompt(value) {
        const ssid = pendingHiddenSsid;
        const password = value.length > 0 ? value : null;
        cancelPrompt();
        runConnect(["nm-wifi", "connect", ssid, "--hidden", "--json"], ssid, password);
    }

    function submitEnterpriseIdentityPrompt(value) {
        if (value.length === 0) {
            status = "Enter an enterprise Wi-Fi identity.";
            return;
        }
        const ap = promptNetwork;
        if (ap)
            openEnterprisePasswordPrompt(ap, value);
    }

    function submitEnterprisePasswordPrompt(value) {
        if (value.length === 0) {
            status = "Enter an enterprise Wi-Fi password.";
            return;
        }
        const ap = promptNetwork;
        const identity = pendingEnterpriseIdentity;
        cancelPrompt();
        if (ap && identity.length > 0)
            runConnect(["nm-wifi", "connect-target", JSON.stringify(enterpriseTarget(ap, identity)), "--json"], networkName(ap), value);
    }

    function submitPrompt() {
        const handlers = {
            "enterprise-identity": submitEnterpriseIdentityPrompt,
            "enterprise-password": submitEnterprisePasswordPrompt,
            "hidden-password": submitHiddenPasswordPrompt,
            "hidden-ssid": submitHiddenSsidPrompt,
            "network-password": submitNetworkPasswordPrompt
        };
        if (handlers[promptMode])
            handlers[promptMode](promptText);
    }

    function acceptKey(event, action) {
        action();
        event.accepted = true;
    }

    function isEnterKey(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter;
    }

    function moveSelection(delta) {
        selectedIndex = clampIndex(selectedIndex + delta, filteredNetworks.length);
    }

    function handleBinding(event, bindings) {
        for (let i = 0; i < bindings.length; i++) {
            if (event.key === bindings[i][0])
                return acceptKey(event, bindings[i][1]);
        }
    }

    function handleSearchKey(event) {
        if (promptOpen)
            return;
        if (isEnterKey(event.key))
            return acceptKey(event, connectSelected);
        return handleBinding(event, [[Qt.Key_Escape, Qt.quit], [Qt.Key_Down, function () {
                    moveSelection(1);
                }], [Qt.Key_Up, function () {
                    moveSelection(-1);
                }], [Qt.Key_F6, openHiddenNetworkPrompt], [Qt.Key_F5, refresh]]);
    }

    onPromptOpenChanged: {
        if (promptOpen)
            Qt.callLater(function () {
                promptInput.forceActiveFocus();
                promptInput.selectAll();
            });
        else
            Qt.callLater(function () {
                search.forceActiveFocus();
            });
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    if (root.scanSnapshotSeen)
                        return;
                    const networks = JSON.parse(text);
                    root.applyNetworks(networks, true);
                    root.status = networks.length + " cached networks; scanning in background…";
                } catch (error) {
                    root.status = "Could not parse nm-wifi networks output: " + error;
                }
            }
        }
        stderr: StdioCollector {
            id: listErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && !root.scanSnapshotSeen)
                root.status = "Cached list failed: " + listErr.text;
            root.maybeRunPendingRefresh();
        }
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            id: statusOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: statusErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.status = "Status failed: " + statusErr.text;
                return;
            }
            try {
                root.activeStatus = JSON.parse(statusOut.text);
                root.applyNetworks(root.networks, false);
            } catch (error) {
                root.status = "Could not parse nm-wifi status output: " + error;
            }
        }
    }

    Process {
        id: scanStreamProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (data) {
                root.handleScanEvent(data);
            }
        }
        stderr: StdioCollector {
            id: scanStreamErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && scanStreamErr.text.length > 0)
                root.status = "Background scan failed: " + scanStreamErr.text;
            root.maybeRunPendingRefresh();
        }
    }

    Process {
        id: connectProc
        stdout: StdioCollector {
            id: connectOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: connectErr
            waitForEnd: true
        }
        onStarted: {
            if (root.pendingConnectUsesStdin) {
                connectProc.write(root.pendingConnectPassword + "\n");
                root.pendingConnectPassword = "";
            }
        }
        onExited: function (exitCode, exitStatus) {
            root.pendingConnectPassword = "";
            root.pendingConnectUsesStdin = false;
            connectProc.stdinEnabled = false;

            try {
                const result = JSON.parse(connectOut.text);
                root.applyConnectResult(result);
                if (result.status !== "error")
                    root.refresh();
                return;
            } catch (error) {
                if (exitCode !== 0) {
                    root.status = "Connect failed: " + (connectErr.text || error);
                    return;
                }
                root.status = "Connected to " + root.lastConnectedSsid + "; could not parse connect result: " + error;
            }
            root.refresh();
        }
    }

    Process {
        id: disconnectProc
        stdout: StdioCollector {
            id: disconnectOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: disconnectErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.status = "Disconnect failed: " + disconnectErr.text;
                return;
            }
            try {
                const result = JSON.parse(disconnectOut.text);
                root.status = result.message || "Disconnected Wi-Fi";
            } catch (error) {
                root.status = "Disconnected Wi-Fi";
            }
            root.refresh();
        }
    }

    Process {
        id: profileProc
        stderr: StdioCollector {
            id: profileErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.status = "Profile action failed: " + profileErr.text;
                return;
            }
            root.status = "Saved profile updated";
            root.refresh();
        }
    }

    Process {
        id: portalProc
        stderr: StdioCollector {
            id: portalErr
            waitForEnd: false
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && portalErr.text.length > 0)
                root.status = "Could not open captive portal browser: " + portalErr.text;
        }
    }

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1040
        implicitHeight: 720
        title: "Shelllist Wi-Fi"
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: "#0b1220"
            border.color: "#243244"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 10
                        Layout.alignment: Qt.AlignVCenter
                        color: "#15335f"
                        Text {
                            anchors.centerIn: parent
                            text: "󰤨"
                            color: "#7dd3fc"
                            font.pixelSize: 18
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "Shelllist Wi-Fi"
                        color: "#dbeafe"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    TextInput {
                        id: search
                        Layout.preferredWidth: 270
                        Layout.preferredHeight: 34
                        Layout.alignment: Qt.AlignVCenter
                        focus: true
                        leftPadding: 38
                        rightPadding: 12
                        color: "#dbeafe"
                        selectionColor: "#2563eb"
                        selectedTextColor: "white"
                        font.pixelSize: 15
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.filterText
                        onTextChanged: {
                            root.filterText = text;
                            root.selectedIndex = 0;
                        }
                        Keys.onPressed: function (event) {
                            root.handleSearchKey(event);
                        }

                        Text {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⌕"
                            color: "#64748b"
                            font.pixelSize: 22
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: "#111827"
                            border.color: "#233247"
                            z: -1
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 8
                        Layout.alignment: Qt.AlignVCenter
                        color: "transparent"
                        border.color: "#233247"
                        Text {
                            anchors.centerIn: parent
                            text: "↻"
                            color: "#94a3b8"
                            font.pixelSize: 20
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.refresh()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "☰   –   ◻   ×"
                        color: "#94a3b8"
                        font.pixelSize: 16
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 425
                        Layout.fillHeight: true
                        radius: 12
                        color: "#0f172a"
                        border.color: "#1f2a3a"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            ListView {
                                id: list
                                width: parent.width
                                height: parent.height
                                clip: true
                                model: root.filteredNetworks
                                spacing: 3

                                delegate: NetworkListRow {
                                    active: root.isActive(modelData)
                                    name: root.networkName(modelData)
                                    selectedIndex: root.selectedIndex
                                    onPicked: function (rowIndex) {
                                        root.selectedIndex = rowIndex;
                                    }
                                    onConnectRequested: root.connectSelected()
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: "#0f172a"
                        border.color: "#1f2a3a"

                        Item {
                            anchors.fill: parent
                            anchors.margins: 18

                            Column {
                                visible: root.hasSelection
                                anchors.fill: parent
                                spacing: 14

                                RowLayout {
                                    width: parent.width
                                    height: 72
                                    spacing: 16

                                    Text {
                                        Layout.preferredWidth: 54
                                        Layout.alignment: Qt.AlignVCenter
                                        text: "󰤨"
                                        color: "#dbeafe"
                                        font.pixelSize: 42
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 5

                                        Text {
                                            width: parent.width
                                            text: root.networkName(root.detailAp)
                                            color: "#f8fafc"
                                            font.pixelSize: 24
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: root.isActive(root.detailAp) ? "Connected · " + (root.detailAp.strength || 0) + "% signal" : root.securityLabel(root.detailAp.security) + " · " + (root.detailAp.strength || 0) + "% signal"
                                            color: root.isActive(root.detailAp) ? "#4ade80" : "#94a3b8"
                                            font.pixelSize: 14
                                        }
                                    }
                                }

                                RowLayout {
                                    width: parent.width
                                    height: 46
                                    spacing: 8

                                    ActionButton {
                                        Layout.preferredWidth: 112
                                        label: root.isActive(root.detailAp) ? "Disconnect" : "Connect"
                                        backgroundColor: root.isActive(root.detailAp) ? "#1e3a5f" : "#1d4ed8"
                                        borderColor: "#3b82f6"
                                        labelColor: "#dbeafe"
                                        enabled: root.canUsePrimaryAction()
                                        onClicked: root.isActive(root.detailAp) ? root.disconnectSelected() : root.connectSelected()
                                    }

                                    ActionButton {
                                        Layout.preferredWidth: 90
                                        label: "Forget"
                                        enabled: root.canEditProfile()
                                        onClicked: root.forgetSelected()
                                    }

                                    ActionButton {
                                        Layout.preferredWidth: 90
                                        label: "Sign in"
                                        onClicked: root.openPortal()
                                    }

                                    ActionButton {
                                        Layout.preferredWidth: 90
                                        label: "Share"
                                        labelColor: "#94a3b8"
                                        enabled: false
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                DetailCard {
                                    height: 250
                                    title: "Connection"

                                    DetailGrid {
                                        DetailField {
                                            label: "Signal strength"
                                            value: (root.detailAp.strength || 0) + "%"
                                            valueColor: "#60a5fa"
                                            valueBold: true
                                        }
                                        DetailField {
                                            label: "IP address"
                                            value: root.activeIp4Value("address")
                                        }
                                        DetailField {
                                            label: "Frequency"
                                            value: root.frequencyLabel(root.detailAp)
                                        }
                                        DetailField {
                                            label: "Gateway"
                                            value: root.activeIp4Value("gateway")
                                        }
                                        DetailField {
                                            label: "Security"
                                            value: root.securityLabel(root.detailAp.security)
                                        }
                                        DetailField {
                                            label: "Subnet"
                                            value: root.activeDetailValue(root.subnetLabel(root.activeStatus ? root.activeStatus.ip4 : null))
                                        }
                                        DetailField {
                                            label: "Network usage"
                                            value: root.activeDetailValue(root.networkUsageLabel())
                                        }
                                        DetailField {
                                            label: "DNS"
                                            value: root.activeDetailValue(root.dnsLabel(root.activeStatus ? root.activeStatus.ip4 : null))
                                            valueWidth: 220
                                        }
                                    }
                                }

                                DetailCard {
                                    height: 145
                                    title: "Network details"

                                    DetailGrid {
                                        DetailField {
                                            label: "Type"
                                            value: root.wifiType(root.detailAp)
                                        }
                                        DetailField {
                                            label: root.hasDirectionalBitrates() ? "Transmit link speed" : "Link speed"
                                            value: root.activeDetailValue(root.hasDirectionalBitrates() ? root.txBitrateLabel() : root.bitrateLabel())
                                        }
                                        DetailField {
                                            label: "MAC address"
                                            value: root.isActive(root.detailAp) ? root.macLabel() : (root.detailAp.bssid || "—")
                                        }
                                        DetailField {
                                            label: "Receive link speed"
                                            value: root.activeDetailValue(root.rxBitrateLabel())
                                        }
                                    }
                                }

                                DetailCard {
                                    height: 208
                                    title: "Profile settings"

                                    Column {
                                        anchors.fill: parent
                                        spacing: 8

                                        RowLayout {
                                            width: parent.width
                                            height: 34
                                            spacing: 12

                                            Column {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                Text {
                                                    text: "Auto-connect"
                                                    color: "#e5e7eb"
                                                    font.pixelSize: 14
                                                }
                                                Text {
                                                    text: root.profileFor(root.detailAp) ? "Connect automatically when this network is in range" : "Connect once before autoconnect is available"
                                                    color: "#64748b"
                                                    font.pixelSize: 11
                                                }
                                            }

                                            TogglePill {
                                                Layout.preferredWidth: 40
                                                Layout.preferredHeight: 22
                                                Layout.alignment: Qt.AlignVCenter
                                                checked: root.autoconnectEnabled()
                                                opacity: root.canEditProfile() ? 1.0 : 0.45

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: root.canEditProfile()
                                                    onClicked: root.toggleAutoconnectSelected()
                                                }
                                            }
                                        }

                                        RowLayout {
                                            width: parent.width
                                            height: 26
                                            spacing: 12

                                            Text {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                text: "Use randomised MAC"
                                                color: "#e5e7eb"
                                                font.pixelSize: 14
                                            }

                                            TogglePill {
                                                Layout.preferredWidth: 40
                                                Layout.preferredHeight: 22
                                                Layout.alignment: Qt.AlignVCenter
                                                checked: root.randomizedMacEnabled()
                                                opacity: root.canEditProfile() ? 1.0 : 0.45

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: root.canEditProfile()
                                                    onClicked: root.setMacRandomizedSelected(!root.randomizedMacEnabled())
                                                }
                                            }
                                        }

                                        RowLayout {
                                            width: parent.width
                                            height: 26
                                            spacing: 12

                                            Text {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                text: "Use device MAC"
                                                color: "#cbd5e1"
                                                font.pixelSize: 14
                                            }

                                            TogglePill {
                                                Layout.preferredWidth: 40
                                                Layout.preferredHeight: 22
                                                Layout.alignment: Qt.AlignVCenter
                                                checked: !root.randomizedMacEnabled()
                                                opacity: root.canEditProfile() ? 1.0 : 0.45

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: root.canEditProfile()
                                                    onClicked: root.setMacRandomizedSelected(false)
                                                }
                                            }
                                        }

                                        RowLayout {
                                            width: parent.width
                                            height: 26
                                            spacing: 12

                                            Column {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                Text {
                                                    text: "Send device name"
                                                    color: "#e5e7eb"
                                                    font.pixelSize: 14
                                                }
                                                Text {
                                                    text: "Share this device's name with the network"
                                                    color: "#64748b"
                                                    font.pixelSize: 11
                                                }
                                            }

                                            TogglePill {
                                                Layout.preferredWidth: 40
                                                Layout.preferredHeight: 22
                                                Layout.alignment: Qt.AlignVCenter
                                                checked: root.sendHostnameEnabled()
                                                opacity: root.canEditProfile() ? 1.0 : 0.45

                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: root.canEditProfile()
                                                    onClicked: root.toggleSendHostnameSelected()
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    width: parent.width
                                    height: 20
                                    Text {
                                        text: root.isActive(root.detailAp) && root.activeStatus && root.activeStatus.active_since_ms ? "Connected" : ""
                                        color: "#64748b"
                                        font.pixelSize: 12
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: root.lastSeenLabel(root.detailAp)
                                        color: "#64748b"
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            Text {
                                visible: !root.hasSelection
                                anchors.centerIn: parent
                                text: "Select a network"
                                color: "#94a3b8"
                                font.pixelSize: 22
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.promptOpen
                anchors.fill: parent
                z: 10
                color: "#99000000"

                MouseArea {
                    anchors.fill: parent
                }

                Rectangle {
                    width: Math.min(parent.width * 0.9, 560)
                    height: 230
                    anchors.centerIn: parent
                    radius: 16
                    color: "#0f172a"
                    border.color: "#38bdf8"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12

                        Text {
                            width: parent.width
                            text: root.promptTitle
                            color: "#f8fafc"
                            font.pixelSize: 22
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.promptDetail
                            color: "#94a3b8"
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        TextInput {
                            id: promptInput
                            width: parent.width
                            height: 44
                            color: "#e5e7eb"
                            selectionColor: "#2563eb"
                            selectedTextColor: "white"
                            font.pixelSize: 19
                            text: root.promptText
                            echoMode: root.promptPassword ? TextInput.Password : TextInput.Normal
                            onTextChanged: root.promptText = text
                            Keys.onPressed: function (event) {
                                if (root.isEnterKey(event.key))
                                    return root.acceptKey(event, root.submitPrompt);
                                if (event.key === Qt.Key_Escape)
                                    return root.acceptKey(event, root.cancelPrompt);
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: "#111827"
                                border.color: "#334155"
                                z: -1
                            }
                        }

                        Text {
                            width: parent.width
                            text: "Enter continue/connect   •   Esc cancel"
                            color: "#64748b"
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
