import Quickshell
import QtQuick
import "Wifi.js" as Wifi
import "."

Item {
    id: controller

    required property var prompt
    required property var windowHost

    property var networks: []
    property var activeStatus: null
    property var networkConnectivity: null
    property string filterText: ""
    property int selectedIndex: 0
    property bool pendingRefresh: false
    property string status: "Loading Wi-Fi networks…"
    property string connectingNetworkName: ""
    property int connectingProgressTick: 0
    property bool scanSnapshotSeen: false
    property bool detailsOpen: false
    property real detailsExpansionProgress: 0
    property var activeHeader: null
    property var activeListPane: null
    property bool shareAvailable: false
    property string sharePayload: ""
    property string shareProfilePath: ""
    property string shareStatus: shareUnavailableMessage
    property double statusHoldUntil: 0
    property double portalOpenHoldUntil: 0
    property string pendingPortalNetworkName: ""
    property var staleSecretKeys: ({})
    property var retryBlockedUntilByAttempt: ({})
    property var lastConnectAp: null
    property string activeScanRequestId: ""
    property string activeConnectRequestId: ""
    property string lastConnectAttemptKey: ""
    property string lastConnectSecretFingerprint: ""

    readonly property int closedWindowWidth: 453
    readonly property int openWindowWidth: 1040
    readonly property int surfaceWindowWidth: openWindowWidth
    readonly property int detailsGapWidth: 12
    readonly property real detailsRenderCutoff: 0.025
    readonly property real detailsPaintProgress: (!detailsOpen && detailsExpansionProgress <= detailsRenderCutoff) ? 0 : detailsExpansionProgress
    readonly property real detailsPaneFullWidth: openWindowWidth - closedWindowWidth - detailsGapWidth
    readonly property real detailsPaneWidth: detailsPaintProgress * detailsPaneFullWidth
    readonly property real detailsPaneGapWidth: detailsPaintProgress * detailsGapWidth
    readonly property bool detailsRendered: detailsOpen || detailsExpansionProgress > detailsRenderCutoff
    readonly property int currentWindowWidth: Math.round(closedWindowWidth + detailsPaintProgress * (openWindowWidth - closedWindowWidth))
    readonly property bool actionInFlight: actions.running
    readonly property bool connectRunning: actions.connectRunning
    readonly property var filteredNetworks: Wifi.visibleNetworks(networks, filterText, activeAccessPoint())
    readonly property var detailAp: selectedNetwork() || ({})
    readonly property bool hasSelection: filteredNetworks.length > 0
    readonly property string busyMessage: "Wait for the current Wi-Fi action to finish…"
    readonly property string shareUnavailableMessage: "Wi-Fi QR sharing is not available for this network."

    function startup() { if (windowHost.floatingMode) refresh(); }
    function selectedNetwork() { return Wifi.selectedNetwork(filteredNetworks, selectedIndex); }
    function activeAccessPoint() { return Wifi.activeAccessPoint(activeStatus); }
    function networkName(ap) { return Wifi.networkName(ap); }
    function isActive(ap) { return Wifi.isActiveAccessPoint(ap, activeAccessPoint()); }
    function profileFor(ap) { return Wifi.profileForAccessPoint(ap, isActive(ap), activeStatus); }
    function autoconnectEnabled() { const profile = profileFor(detailAp); return !!(profile && profile.autoconnect); }
    function randomizedMacEnabled() { return !!Wifi.privacyFor(profileFor(detailAp)).randomized_mac; }
    function sendHostnameEnabled() { return Wifi.privacyFor(profileFor(detailAp)).send_hostname !== false; }
    function canProfileAction(capability) { const caps = detailAp.capabilities || null; return !actionInFlight && !!profileFor(detailAp) && (!caps || caps[capability] !== false); }
    function canForgetProfile() { return canProfileAction("can_forget"); }
    function canToggleAutoconnectProfile() { return canProfileAction("can_toggle_autoconnect"); }
    function canSetMacRandomizationProfile() { return canProfileAction("can_set_mac_randomization"); }
    function canSetSendHostnameProfile() { return canProfileAction("can_set_send_hostname"); }
    function canUsePrimaryAction() { return isActive(detailAp) ? !actionInFlight : canBeginConnectAction(detailAp); }
    function canShareSelected() { return shareAvailable && sharePayload.length > 0; }

    function resetShareAvailability() {
        shareProfilePath = "";
        setShareAvailability(false, "", shareUnavailableMessage);
    }

    function refreshShareAvailability() {
        resetShareAvailability();
        if (!hasSelection)
            return;
        const share = detailAp.share || ({});
        if (Wifi.canShareQr(detailAp))
            return setShareAvailability(true, Wifi.wifiQrPayload(detailAp), "Wi-Fi QR payload is ready.");
        const profilePath = share.profile_path || (profileFor(detailAp) && profileFor(detailAp).path);
        if (!share.requires_profile_secret_check || !profilePath)
            return shareStatus = share.reason || "Wi-Fi QR sharing requires an open network or a saved profile with a readable password.";
        if (sharing.running)
            return;
        shareProfilePath = profilePath;
        shareStatus = "Checking saved Wi-Fi password availability…";
        sharing.check(profilePath);
    }

    function shareSelected() {
        if (!canShareSelected())
            return status = shareStatus;
        Quickshell.clipboardText = sharePayload;
        status = "Wi-Fi QR payload for " + Wifi.networkName(detailAp) + " copied to clipboard";
    }

    function setShareAvailability(available, payload, message) {
        shareAvailable = available;
        sharePayload = payload;
        shareStatus = message;
    }

    function refreshShareAvailabilityIfOpen() { if (detailsOpen) Qt.callLater(refreshShareAvailability); }
    function nowMs() { return Date.now(); }
    function secretStale(ap) { return !!staleSecretKeys[Wifi.secretKey(ap)]; }
    function markSecretStale(ap) {
        if (!ap)
            return;
        staleSecretKeys[Wifi.secretKey(ap)] = true;
        staleSecretKeys = staleSecretKeys;
    }
    function clearSecretStale(ap) {
        if (!ap)
            return;
        delete staleSecretKeys[Wifi.secretKey(ap)];
        staleSecretKeys = staleSecretKeys;
    }
    function blockLastConnectRetry(milliseconds) {
        if (lastConnectAttemptKey.length === 0 || milliseconds <= 0)
            return;
        retryBlockedUntilByAttempt[lastConnectAttemptKey + "\n" + lastConnectSecretFingerprint] = nowMs() + milliseconds;
        retryBlockedUntilByAttempt = retryBlockedUntilByAttempt;
    }
    function retryDelayRemainingMs(ap, password) {
        const until = retryBlockedUntilByAttempt[Wifi.connectAttemptKey(ap) + "\n" + Wifi.passwordFingerprint(password)] || 0;
        return Math.max(0, until - nowMs());
    }
    function rememberConnectAttempt(ap, password) {
        lastConnectAp = ap;
        lastConnectAttemptKey = Wifi.connectAttemptKey(ap);
        lastConnectSecretFingerprint = Wifi.passwordFingerprint(password);
    }
    function statusIsHeld() { return nowMs() < statusHoldUntil; }
    function setBackgroundStatus(message) { if (!statusIsHeld()) status = message; }
    function setHeldStatus(message, milliseconds) { status = message; statusHoldUntil = nowMs() + milliseconds; }
    function applyShareCheckOutput(output, errorText) {
        try {
            const result = Wifi.apiData(JSON.parse(output), "payload");
            if (result.path !== shareProfilePath)
                return refreshShareAvailabilityIfOpen();
            const available = !!result.shareable && !!result.qr_payload;
            setShareAvailability(available, available ? result.qr_payload : "", available ? "Wi-Fi QR payload is ready." : (result.reason || shareUnavailableMessage));
        } catch (error) {
            setShareAvailability(false, "", "Could not check Wi-Fi QR sharing: " + (errorText || error));
        }
    }

    function applyNetworks(newNetworks, resetSelection) {
        const previous = selectedNetwork();
        networks = newNetworks;
        selectedIndex = Wifi.selectedIndexAfterUpdate(previous, filteredNetworks, selectedIndex, resetSelection, isActive);
    }

    function refresh() {
        if (actions.connectRunning) {
            pendingRefresh = true;
            setBackgroundStatus("Connection in progress; delaying Wi-Fi scan refresh…");
            refreshStatus();
            return;
        }
        if (discovery.listRunning || discovery.scanRunning) {
            pendingRefresh = true;
            status = "Refresh already running; queued another refresh…";
            refreshStatus();
            return;
        }
        pendingRefresh = false;
        setBackgroundStatus("Loading cached Wi-Fi networks…");
        scanSnapshotSeen = false;
        discovery.refreshCachedNetworks();
        refreshStatus();
        discovery.startScanStream();
    }
    function maybeRunPendingRefresh() { if (pendingRefresh && !actions.connectRunning && !discovery.listRunning && !discovery.scanRunning) Qt.callLater(refresh); }
    function refreshStatus() { discovery.refreshStatus(); }

    function scanEventStatus(event) {
        switch (event.event) {
        case "snapshot": return event.networks_found + (event.scanning ? " networks found; scanning…" : " networks available");
        case "complete": return event.networks_found + (event.timed_out ? " networks available; scan timed out" : " networks available");
        case "status":
        case "warning":
        case "failed":
        case "cancelled": return event.message || status;
        default: return status;
        }
    }
    function applyScanEvent(event) {
        if (event.event === "snapshot") {
            scanSnapshotSeen = true;
            applyNetworks(event.networks || [], false);
        }
        setBackgroundStatus(scanEventStatus(event));
        if (event.event === "complete")
            refreshStatus();
    }
    function handleScanEvent(line) {
        const trimmed = line.trim();
        if (!trimmed)
            return;
        try { applyScanEvent(JSON.parse(trimmed)); }
        catch (error) { status = "Could not parse scan event: " + error; }
    }

    function connectEventResult(event) {
        if (event.result)
            return event.result;
        return { status: "error", reason: event.reason || "unknown", message: event.message || "Connection failed" };
    }

    function handleConnectEvent(event) {
        if (!event.request_id || event.request_id !== activeConnectRequestId)
            return;
        switch (event.event) {
        case "started":
        case "progress":
            setBackgroundStatus(event.message || "Connecting to " + connectingNetworkName + "…");
            return;
        case "succeeded":
            activeConnectRequestId = "";
            resetConnectProgress();
            applyConnectResult(connectEventResult(event), event.message || "Connected");
            refresh();
            return;
        case "failed":
        case "cancelled":
            activeConnectRequestId = "";
            resetConnectProgress();
            applyConnectResult(connectEventResult(event), event.message || "Connection failed");
            return;
        }
    }

    function handleSecretEvent(event) {
        if (event.event === "requested") {
            prompt.openDaemonSecretPrompt(event);
            return;
        }
        if (event.event === "cancelled" && prompt.mode === "daemon-secret" && prompt.secretRequestId === event.request_id) {
            prompt.cancel();
            status = "NetworkManager cancelled the Wi-Fi secret request.";
        }
    }

    function handleDaemonEvent(line) {
        const trimmed = line.trim();
        if (!trimmed)
            return;
        try {
            const event = JSON.parse(trimmed);
            if (event.stream === "wifi.scan") {
                if (event.request_id && event.request_id === activeScanRequestId) {
                    applyScanEvent(event);
                    if (event.event === "complete" || event.event === "failed" || event.event === "cancelled") {
                        activeScanRequestId = "";
                        maybeRunPendingRefresh();
                    }
                }
            } else if (event.stream === "wifi.connect") {
                handleConnectEvent(event);
            } else if (event.stream === "wifi.secret") {
                handleSecretEvent(event);
            }
        } catch (error) {
            status = "Could not parse nm-daemon event: " + error;
        }
    }

    function requireIdle(ready) {
        if (!ready)
            status = busyMessage;
        return ready;
    }
    function beginAction() { return requireIdle(!actionInFlight); }
    function canBeginAnyConnectAction() { return !actions.running; }
    function canBeginConnectAction(ap) { return canBeginAnyConnectAction() && Wifi.canStartConnection(ap); }
    function beginAnyConnectAction() { return requireIdle(canBeginAnyConnectAction()); }
    function beginConnectAction(ap) { return requireIdle(canBeginConnectAction(ap)); }
    function primarySelected() { return isActive(selectedNetwork()) ? disconnectSelected() : connectSelected(); }
    function isConnecting(ap) { return actions.connectRunning && connectingNetworkName.length > 0 && Wifi.networkName(ap) === connectingNetworkName && !isActive(ap); }
    function connectingNetworkIsActive() { return connectingNetworkName.length > 0 && Wifi.networkName(activeAccessPoint()) === connectingNetworkName; }
    function updateVisibleConnectProgress() {
        if (!actions.connectRunning || !connectingNetworkIsActive())
            return;
        setHeldStatus("Connected to " + connectingNetworkName, 2500);
        openPendingPortal();
        connectingProgressTimer.stop();
        connectStatusPollTimer.stop();
    }
    function deferConnectForPrompt(ap) {
        if (secretStale(ap)) {
            prompt.openPasswordPrompt(ap, "Saved password failed. Enter a new Wi-Fi password.");
            return true;
        }
        if (Wifi.needsPassword(ap)) {
            prompt.openPasswordPrompt(ap);
            return true;
        }
        if (Wifi.needsCredentials(ap)) {
            prompt.openEnterpriseIdentityPrompt(ap);
            return true;
        }
        if (Wifi.canConnect(ap))
            return false;
        status = "This access point cannot be connected from Shelllist yet. Use F6 for hidden SSIDs.";
        return true;
    }
    function connectSelected() {
        const ap = selectedNetwork();
        if (!ap || !beginConnectAction(ap))
            return;
        if (!deferConnectForPrompt(ap))
            runConnectTarget(ap, Wifi.networkName(ap));
    }
    function connectTargetRequest(ap, password) {
        const request = { target: Wifi.connectTarget(ap) };
        if (password !== undefined && password !== null)
            request.password = password;
        return JSON.stringify(request);
    }
    function shouldAutoOpenPortal(ap, password) { return !!ap && ap.portal_hint && ap.portal_hint.auto_open_on_connect && (password === undefined || password === null); }
    function schedulePortalForConnect(ap, displayName, password) {
        pendingPortalNetworkName = shouldAutoOpenPortal(ap, password) ? displayName : "";
        if (pendingPortalNetworkName.length > 0)
            captivePortalOpenTimer.restart();
    }
    function openPendingPortal() {
        if (pendingPortalNetworkName.length === 0 || pendingPortalNetworkName !== connectingNetworkName)
            return;
        pendingPortalNetworkName = "";
        openPortal();
    }
    function runConnectTarget(ap, displayName, password) {
        const attemptKey = Wifi.connectAttemptKey(ap);
        const secretFingerprint = Wifi.passwordFingerprint(password);
        if (actions.connectRunning && lastConnectAttemptKey === attemptKey && lastConnectSecretFingerprint === secretFingerprint) {
            status = "Connection attempt for " + displayName + " is already running…";
            return;
        }
        const retryDelay = retryDelayRemainingMs(ap, password);
        if (retryDelay > 0) {
            status = "Waiting " + Math.ceil(retryDelay / 1000) + "s before retrying " + displayName + "; NetworkManager is temporarily ignoring this AP.";
            return;
        }
        rememberConnectAttempt(ap, password);
        schedulePortalForConnect(ap, displayName, password);
        runConnect(["shelllist-nm-daemon-call", "wifi.connectTarget", "--stdin"], displayName, connectTargetRequest(ap, password));
    }
    function runConnect(args, displayName, stdinText) {
        if (!requireIdle(!actions.nonConnectRunning))
            return;
        if (pendingPortalNetworkName !== displayName)
            pendingPortalNetworkName = "";
        status = actions.connectRunning ? "Connection attempt already running…" : "Connecting to " + displayName + "…";
        connectingNetworkName = displayName;
        connectingProgressTick = 0;
        connectingProgressTimer.restart();
        connectStatusPollTimer.restart();
        Qt.callLater(refreshStatus);
        actions.runConnect(args.slice(), stdinText);
    }
    function resetConnectProgress() { connectingNetworkName = ""; connectingProgressTick = 0; connectingProgressTimer.stop(); connectStatusPollTimer.stop(); }
    function applyConnectResult(result, fallbackText) {
        const message = Wifi.connectResultMessage(result, fallbackText);
        if (result.status === "error") {
            status = message;
            if (Wifi.isSecretFailureReason(result.reason)) {
                markSecretStale(lastConnectAp);
                blockLastConnectRetry(Wifi.connectFailureRetryMs(result.reason));
                if (lastConnectAp)
                    prompt.openPasswordPrompt(lastConnectAp, Wifi.isWrongPasswordReason(result.reason) ? "Wrong password. Enter a new Wi-Fi password." : "Saved password failed. Enter a new Wi-Fi password.");
            }
        } else {
            clearSecretStale(lastConnectAp);
            setHeldStatus(message, 2500);
        }
        if (result.status !== "error" && result.suggest_open_portal)
            openPortal();
        maybeRunPendingRefresh();
    }
    function provideSecret(requestId, password, save) {
        status = "Sending requested Wi-Fi secret to NetworkManager…";
        actions.provideSecret(requestId, password, save);
    }
    function disconnectSelected() {
        if (!beginAction())
            return;
        status = "Disconnecting Wi-Fi…";
        actions.disconnect();
    }
    function runProfileAction(action) {
        if (!beginAction())
            return;
        const profile = profileFor(selectedNetwork());
        if (profile)
            action(profile);
    }
    function forgetSelected() { runProfileAction(function (profile) { status = "Forgetting saved profile " + profile.id + "…"; actions.deleteProfile(profile.path); }); }
    function toggleAutoconnectSelected() { runProfileAction(function (profile) { const enabled = !profile.autoconnect; status = (enabled ? "Enabling" : "Disabling") + " autoconnect for " + profile.id + "…"; actions.setAutoconnect(profile.path, enabled); }); }
    function setMacRandomizedSelected(enabled) { runProfileAction(function (profile) { status = (enabled ? "Using randomized MAC for " : "Using device MAC for ") + profile.id + "…"; actions.setMacRandomization(profile.path, enabled); }); }
    function toggleSendHostnameSelected() { runProfileAction(function (profile) { const enabled = !(profile.privacy && profile.privacy.send_hostname !== false); status = (enabled ? "Sending" : "Hiding") + " device name for " + profile.id + "…"; actions.setSendHostname(profile.path, enabled); }); }
    function openPortal() {
        if (nowMs() < portalOpenHoldUntil)
            return;
        portalOpenHoldUntil = nowMs() + 12000;
        status = "Opening captive portal page…";
        actions.openPortal();
    }
    function canConnectDetail() { return !isActive(detailAp) && canUsePrimaryAction(); }
    function canDisconnectDetail() { return isActive(detailAp) && canUsePrimaryAction(); }
    function toggleRandomizedMacSelected() { setMacRandomizedSelected(!randomizedMacEnabled()); }

    function acceptKey(event, action) { action(); event.accepted = true; }
    function isEnterKey(key) { return key === Qt.Key_Return || key === Qt.Key_Enter; }
    function isPlainHotkey(event, key) { return event.key === key && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier); }
    function moveSelection(delta) { selectedIndex = Wifi.clampIndex(selectedIndex + delta, filteredNetworks.length); }
    function openDetailsPane() {
        if (!detailsOpen) {
            detailsOpen = true;
            detailsExpansionProgress = 1;
            Qt.callLater(windowHost.requestWindowPlacement);
        }
    }
    function closeDetailsPane() {
        if (detailsOpen) {
            detailsOpen = false;
            detailsExpansionProgress = 0;
            Qt.callLater(windowHost.requestWindowPlacement);
        }
    }
    function toggleDetailsPane() { detailsOpen ? closeDetailsPane() : openDetailsPane(); }
    function focusNetworkListTop() { selectedIndex = 0; if (activeListPane) Qt.callLater(activeListPane.focusTop); }
    function focusSearchBox() { if (activeHeader) Qt.callLater(activeHeader.focusSearch); }
    function closeRequested() { windowHost.closeRequested(); }
    function openHiddenNetworkPrompt() { if (beginAnyConnectAction()) prompt.openHiddenNetworkPrompt(); }

    function handleBinding(event, bindings) {
        for (let i = 0; i < bindings.length; i++)
            if (event.key === bindings[i][0])
                return acceptKey(event, bindings[i][1]);
    }
    function paneBindings(downAction) {
        return [[Qt.Key_Escape, closeRequested], [Qt.Key_Down, downAction], [Qt.Key_Up, function () { moveSelection(-1); }], [Qt.Key_Right, openDetailsPane], [Qt.Key_Left, closeDetailsPane], [Qt.Key_F6, openHiddenNetworkPrompt], [Qt.Key_F5, refresh]];
    }
    function handleSearchKey(event) {
        if (prompt.open)
            return;
        if (isEnterKey(event.key))
            return acceptKey(event, primarySelected);
        return handleBinding(event, paneBindings(focusNetworkListTop));
    }
    function handleDetailHotkey(event) {
        if (!detailsOpen)
            return false;
        const bindings = [
            [Qt.Key_C, canConnectDetail, connectSelected],
            [Qt.Key_D, canDisconnectDetail, disconnectSelected],
            [Qt.Key_F, canForgetProfile, forgetSelected],
            [Qt.Key_I, function () { return hasSelection; }, openPortal],
            [Qt.Key_S, canShareSelected, shareSelected],
            [Qt.Key_A, canToggleAutoconnectProfile, toggleAutoconnectSelected],
            [Qt.Key_R, canSetMacRandomizationProfile, toggleRandomizedMacSelected],
            [Qt.Key_N, canSetSendHostnameProfile, toggleSendHostnameSelected]
        ];
        const binding = bindings.find(function (item) { return isPlainHotkey(event, item[0]) && item[1](); });
        if (!binding)
            return false;
        acceptKey(event, binding[2]);
        return true;
    }
    function handleListKey(event) {
        if (isEnterKey(event.key))
            return acceptKey(event, primarySelected);
        if (handleDetailHotkey(event))
            return;
        if (event.key === Qt.Key_Up && selectedIndex <= 0)
            return acceptKey(event, focusSearchBox);
        return handleBinding(event, paneBindings(function () { moveSelection(1); }));
    }

    onDetailsOpenChanged: {
        if (detailsOpen) {
            Qt.callLater(refreshStatus);
            Qt.callLater(refreshShareAvailability);
        }
    }
    onSelectedIndexChanged: if (detailsOpen) { Qt.callLater(refreshStatus); Qt.callLater(refreshShareAvailability); }
    onActiveStatusChanged: updateVisibleConnectProgress()

    Connections { target: prompt; function onOpenChanged() { if (!prompt.open) Qt.callLater(focusSearchBox); } }
    Behavior on detailsExpansionProgress {
        enabled: !controller.windowHost.noAnimations
        NumberAnimation {
            duration: 220
            easing.type: Easing.InOutSine
        }
    }
    Timer { id: connectingProgressTimer; interval: 120; repeat: true; onTriggered: controller.connectingProgressTick += 1 }
    Timer { id: connectStatusPollTimer; interval: 750; repeat: true; onTriggered: controller.refreshStatus() }
    Timer { id: captivePortalOpenTimer; interval: 2500; repeat: false; onTriggered: controller.openPendingPortal() }
    NmDaemonEvents { id: daemonEvents; controller: controller }
    WifiDiscoveryProcesses { id: discovery; controller: controller }
    WifiActionProcesses { id: actions; controller: controller }
    WifiShareProcess { id: sharing; controller: controller }
}
