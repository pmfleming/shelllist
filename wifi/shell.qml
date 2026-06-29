import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "Wifi.js" as Wifi
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
    property bool detailsOpen: false
    property int floatingPlacementAttempts: 0
    readonly property int closedWindowWidth: 453
    readonly property int openWindowWidth: 1040
    readonly property int currentWindowWidth: detailsOpen ? openWindowWidth : closedWindowWidth
    readonly property int currentWindowHeight: Math.round((((window && window.screen && window.screen.height > 0) ? window.screen.height : 960) * 0.75))
    property var promptNetwork: null
    property string pendingHiddenSsid: ""
    property bool pendingConnectUsesStdin: false
    property string pendingConnectStdinText: ""
    property string pendingEnterpriseIdentity: ""
    property bool shareAvailable: false
    property string sharePayload: ""
    property string shareProfilePath: ""
    property string shareStatus: "Wi-Fi QR sharing is not available for this network."

    readonly property bool actionInFlight: connectProc.running || disconnectProc.running || profileProc.running
    readonly property var filteredNetworks: networks.filter(function (ap) {
        return !root.filterText || (ap.ssid || "").toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1;
    }).sort(function (left, right) {
        const leftActive = root.isActive(left);
        const rightActive = root.isActive(right);
        return leftActive === rightActive ? 0 : leftActive ? -1 : 1;
    })
    readonly property var detailAp: selectedNetwork() || ({})
    readonly property bool hasSelection: filteredNetworks.length > 0

    function clampIndex(index, length) {
        return Wifi.clampIndex(index, length);
    }

    function selectedNetwork() {
        if (filteredNetworks.length === 0)
            return null;
        return filteredNetworks[clampIndex(selectedIndex, filteredNetworks.length)];
    }

    function activeAccessPoint() {
        return activeStatus ? activeStatus.access_point || (activeStatus.network || null) : null;
    }

    function isActive(ap) {
        if (!ap)
            return false;
        const active = activeAccessPoint();
        if (ap.active || Wifi.sameAccessPoint(ap, active))
            return true;
        return (ap.access_points || []).some(function (child) {
            return child.active || Wifi.sameAccessPoint(child, active);
        });
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

    function autoconnectEnabled() {
        const profile = profileFor(detailAp);
        return !!(profile && profile.autoconnect);
    }

    function randomizedMacEnabled() {
        return !!Wifi.privacyFor(profileFor(detailAp)).randomized_mac;
    }

    function sendHostnameEnabled() {
        return Wifi.privacyFor(profileFor(detailAp)).send_hostname !== false;
    }

    function canEditProfile() {
        return !actionInFlight && !!profileFor(detailAp);
    }

    function canUsePrimaryAction() {
        return !actionInFlight && (isActive(detailAp) || Wifi.canStartConnection(detailAp));
    }

    function canShareSelected() {
        return shareAvailable && sharePayload.length > 0;
    }

    function refreshShareAvailability() {
        shareAvailable = false;
        sharePayload = "";
        shareProfilePath = "";
        shareStatus = "Wi-Fi QR sharing is not available for this network.";

        if (!hasSelection)
            return;

        if (Wifi.canShareQr(detailAp)) {
            sharePayload = Wifi.wifiQrPayload(detailAp);
            shareAvailable = true;
            shareStatus = "Wi-Fi QR payload is ready.";
            return;
        }

        const profile = profileFor(detailAp);
        if (!profile || !profile.path) {
            shareStatus = "Wi-Fi QR sharing requires an open network or a saved profile with a readable password.";
            return;
        }

        if (shareCheckProc.running)
            return;

        shareProfilePath = profile.path;
        shareStatus = "Checking saved Wi-Fi password availability…";
        shareCheckProc.exec(["nm-api", "profile", "share", profile.path, "--json"]);
    }

    function shareSelected() {
        if (!canShareSelected()) {
            status = shareStatus;
            return;
        }

        Quickshell.clipboardText = sharePayload;
        status = "Wi-Fi QR payload for " + Wifi.networkName(detailAp) + " copied to clipboard";
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
                return Wifi.sameAccessPoint(previous, ap);
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
        listProc.exec(["nm-api", "networks", "--cached", "--json"]);
        refreshStatus();
        startScanStream();
    }

    function maybeRunPendingRefresh() {
        if (pendingRefresh && !listProc.running && !scanStreamProc.running)
            Qt.callLater(refresh);
    }

    function refreshStatus() {
        if (!statusProc.running)
            statusProc.exec(["nm-api", "status", "--json"]);
    }

    function startScanStream() {
        if (!scanStreamProc.running)
            scanStreamProc.exec(["nm-api", "scan", "--stream", "--cache", "--timeout", "12"]);
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

    function primarySelected() {
        const ap = selectedNetwork();
        if (isActive(ap))
            return disconnectSelected();
        return connectSelected();
    }

    function connectSelected() {
        if (!beginAction())
            return;

        const ap = selectedNetwork();
        if (!ap)
            return;
        if (Wifi.needsPassword(ap)) {
            openPasswordPrompt(ap);
            return;
        }
        if (Wifi.needsCredentials(ap)) {
            openEnterpriseIdentityPrompt(ap);
            return;
        }
        if (!Wifi.canConnect(ap)) {
            status = "This access point cannot be connected from Shelllist yet. Use F6 for hidden SSIDs.";
            return;
        }

        runConnectTarget(ap, Wifi.networkName(ap));
    }

    function connectTargetRequest(ap, password) {
        const request = { target: ap };
        if (password !== undefined && password !== null)
            request.password = password;
        return JSON.stringify(request);
    }

    function runConnectTarget(ap, displayName, password) {
        runConnect(["nm-api", "connect-target", "--json"], displayName, connectTargetRequest(ap, password));
    }

    function runConnect(args, displayName, stdinText) {
        if (!beginAction())
            return;

        pendingConnectUsesStdin = stdinText !== undefined && stdinText !== null;
        pendingConnectStdinText = pendingConnectUsesStdin ? stdinText : "";
        const commandArgs = args.slice();

        status = "Connecting to " + displayName + "…";
        lastConnectedSsid = displayName;
        connectProc.stdinEnabled = pendingConnectUsesStdin;
        connectProc.exec(commandArgs);
    }

    function applyConnectResult(result) {
        const connectivity = result.connectivity || {};
        if (result.status === "error") {
            status = Wifi.connectFailureMessage(result, connectErr.text);
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
        disconnectProc.exec(["nm-api", "disconnect", "--json"]);
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
            profileProc.exec(["nm-api", "profile", "delete", profile.path]);
        });
    }

    function toggleAutoconnectSelected() {
        runProfileAction(function (profile) {
            const enabled = !profile.autoconnect;
            status = (enabled ? "Enabling" : "Disabling") + " autoconnect for " + profile.id + "…";
            profileProc.exec(["nm-api", "profile", "autoconnect", profile.path, enabled ? "true" : "false"]);
        });
    }

    function setMacRandomizedSelected(enabled) {
        runProfileAction(function (profile) {
            status = (enabled ? "Using randomized MAC for " : "Using device MAC for ") + profile.id + "…";
            profileProc.exec(["nm-api", "profile", "mac-randomization", profile.path, enabled ? "true" : "false"]);
        });
    }

    function toggleSendHostnameSelected() {
        runProfileAction(function (profile) {
            const enabled = !(profile.privacy && profile.privacy.send_hostname !== false);
            status = (enabled ? "Sending" : "Hiding") + " device name for " + profile.id + "…";
            profileProc.exec(["nm-api", "profile", "send-hostname", profile.path, enabled ? "true" : "false"]);
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
        openPrompt("network-password", "Password for " + Wifi.networkName(ap), "Enter the Wi-Fi password, then press Enter.", true, ap, "");
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
        openPrompt("enterprise-identity", "Enterprise identity for " + Wifi.networkName(ap), detail, false, ap, "");
    }

    function openEnterprisePasswordPrompt(ap, identity) {
        pendingEnterpriseIdentity = identity;
        openPrompt("enterprise-password", "Enterprise password for " + identity, "Enter your enterprise Wi-Fi password, then press Enter.", true, ap, "");
    }

    function submitNetworkPasswordPrompt(value) {
        if (value.length === 0) {
            status = "Enter a password for this network.";
            return;
        }

        const ap = promptNetwork;
        cancelPrompt();
        if (ap)
            runConnectTarget(ap, Wifi.networkName(ap), value);
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
        const args = ["nm-api", "connect", ssid, "--hidden", "--json"];
        if (password !== null)
            args.push("--password-stdin");
        runConnect(args, ssid, password);
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
            runConnectTarget(Wifi.enterpriseTarget(ap, identity), Wifi.networkName(ap), value);
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

    function targetWindowX() {
        const currentScreen = window && window.screen ? window.screen : null;
        const screenX = currentScreen ? currentScreen.x || 0 : 0;
        const screenWidth = currentScreen && currentScreen.width > 0 ? currentScreen.width : 1280;
        return Math.round(screenX + (screenWidth - currentWindowWidth) / 2);
    }

    function targetWindowY() {
        const currentScreen = window && window.screen ? window.screen : null;
        const screenY = currentScreen ? currentScreen.y || 0 : 0;
        const screenHeight = currentScreen && currentScreen.height > 0 ? currentScreen.height : 960;
        return Math.round(screenY + screenHeight * 0.125);
    }

    function requestFloatingPlacement() {
        if (!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            return;
        floatingPlacementAttempts = 0;
        floatingPlacementTimer.restart();
    }

    function openDetailsPane() {
        if (!detailsOpen) {
            detailsOpen = true;
            Qt.callLater(requestFloatingPlacement);
        }
    }

    function closeDetailsPane() {
        if (detailsOpen) {
            detailsOpen = false;
            Qt.callLater(requestFloatingPlacement);
        }
    }

    function toggleDetailsPane() {
        detailsOpen = !detailsOpen;
        Qt.callLater(requestFloatingPlacement);
    }

    function focusNetworkListTop() {
        selectedIndex = 0;
        Qt.callLater(listPane.focusTop);
    }

    function focusSearchBox() {
        Qt.callLater(header.focusSearch);
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
            return acceptKey(event, primarySelected);
        return handleBinding(event, [[Qt.Key_Escape, Qt.quit], [Qt.Key_Down, focusNetworkListTop], [Qt.Key_Up, function () {
                    moveSelection(-1);
                }], [Qt.Key_Right, openDetailsPane], [Qt.Key_Left, closeDetailsPane], [Qt.Key_F6, openHiddenNetworkPrompt], [Qt.Key_F5, refresh]]);
    }

    function handleListKey(event) {
        if (isEnterKey(event.key))
            return acceptKey(event, primarySelected);
        if (event.key === Qt.Key_Up && selectedIndex <= 0)
            return acceptKey(event, focusSearchBox);
        return handleBinding(event, [[Qt.Key_Escape, Qt.quit], [Qt.Key_Down, function () {
                    moveSelection(1);
                }], [Qt.Key_Up, function () {
                    moveSelection(-1);
                }], [Qt.Key_Right, openDetailsPane], [Qt.Key_Left, closeDetailsPane], [Qt.Key_F6, openHiddenNetworkPrompt], [Qt.Key_F5, refresh]]);
    }

    onPromptOpenChanged: {
        if (!promptOpen)
            Qt.callLater(header.focusSearch);
    }

    onDetailsOpenChanged: {
        if (detailsOpen) {
            Qt.callLater(refreshStatus);
            Qt.callLater(refreshShareAvailability);
        }
    }

    onSelectedIndexChanged: {
        if (detailsOpen) {
            Qt.callLater(refreshStatus);
            Qt.callLater(refreshShareAvailability);
        }
    }

    Component.onCompleted: refresh()

    Timer {
        id: floatingPlacementTimer
        interval: 150
        repeat: true
        onTriggered: {
            root.floatingPlacementAttempts += 1;
            Hyprland.dispatch("focuswindow title:Shelllist Wi-Fi");
            Hyprland.dispatch("setfloating");
            Hyprland.dispatch("resizewindowpixel exact " + root.currentWindowWidth + " " + root.currentWindowHeight + ",title:Shelllist Wi-Fi");
            Hyprland.dispatch("movewindowpixel exact " + root.targetWindowX() + " " + root.targetWindowY() + ",title:Shelllist Wi-Fi");
            if (root.floatingPlacementAttempts >= 8)
                stop();
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    if (root.scanSnapshotSeen)
                        return;
                    const networks = Wifi.apiData(JSON.parse(text), "networks") || [];
                    root.applyNetworks(networks, true);
                    root.status = networks.length + " cached networks; scanning in background…";
                } catch (error) {
                    root.status = "Could not parse nm-api networks response: " + error;
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
                root.activeStatus = Wifi.apiData(JSON.parse(statusOut.text), "status");
                root.applyNetworks(root.networks, false);
                if (root.detailsOpen)
                    Qt.callLater(root.refreshShareAvailability);
            } catch (error) {
                root.status = "Could not parse nm-api status response: " + error;
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
                connectProc.write(root.pendingConnectStdinText + "\n");
                root.pendingConnectStdinText = "";
            }
        }
        onExited: function (exitCode, exitStatus) {
            root.pendingConnectStdinText = "";
            root.pendingConnectUsesStdin = false;
            connectProc.stdinEnabled = false;

            try {
                const result = Wifi.apiResult(JSON.parse(connectOut.text), "result");
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
                const result = Wifi.apiResult(JSON.parse(disconnectOut.text), "result");
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
        id: shareCheckProc
        stdout: StdioCollector {
            id: shareCheckOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: shareCheckErr
            waitForEnd: true
        }
        onExited: function (exitCode, exitStatus) {
            try {
                const result = Wifi.apiData(JSON.parse(shareCheckOut.text), "payload");
                if (result.path !== root.shareProfilePath) {
                    if (root.detailsOpen)
                        Qt.callLater(root.refreshShareAvailability);
                    return;
                }
                root.shareAvailable = !!result.shareable && !!result.qr_payload;
                root.sharePayload = root.shareAvailable ? result.qr_payload : "";
                root.shareStatus = root.shareAvailable ? "Wi-Fi QR payload is ready." : (result.reason || "Wi-Fi QR sharing is not available for this network.");
            } catch (error) {
                root.shareAvailable = false;
                root.sharePayload = "";
                root.shareStatus = "Could not check Wi-Fi QR sharing: " + (shareCheckErr.text || error);
            }
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
        implicitWidth: root.currentWindowWidth
        implicitHeight: root.currentWindowHeight
        title: "Shelllist Wi-Fi"
        color: "transparent"
        onWindowConnected: root.requestFloatingPlacement()

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: "#0b1220"
            border.color: "#243244"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                ColumnLayout {
                    Layout.preferredWidth: 425
                    Layout.maximumWidth: 425
                    Layout.fillHeight: true
                    spacing: 12

                    WifiHeader {
                        id: header
                        filterText: root.filterText
                        onFilterEdited: function (text) {
                            root.filterText = text;
                            root.selectedIndex = 0;
                        }
                        onKeyPressed: function (event) {
                            root.handleSearchKey(event);
                        }
                        onRefreshRequested: root.refresh()
                    }

                    NetworkListPane {
                        id: listPane
                        controller: root
                    }
                }

                NetworkDetailsPane {
                    controller: root
                    visible: root.detailsOpen
                    Layout.fillWidth: root.detailsOpen
                    Layout.preferredWidth: root.detailsOpen ? root.openWindowWidth - root.closedWindowWidth - 12 : 0
                    Layout.maximumWidth: root.detailsOpen ? 9999 : 0
                }
            }

            PromptDialog {
                visible: root.promptOpen
                title: root.promptTitle
                detail: root.promptDetail
                inputText: root.promptText
                password: root.promptPassword
                onInputEdited: function (text) {
                    root.promptText = text;
                }
                onAccepted: root.submitPrompt()
                onCancelled: root.cancelPrompt()
            }
        }
    }
}
