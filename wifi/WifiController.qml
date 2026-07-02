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
    property string shareStatus: "Wi-Fi QR sharing is not available for this network."
    property double statusHoldUntil: 0
    property double portalOpenHoldUntil: 0
    property string pendingPortalNetworkName: ""

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
    readonly property var filteredNetworks: networks.filter(function (ap) {
        return !filterText || (ap.ssid || "").toLowerCase().indexOf(filterText.toLowerCase()) !== -1;
    }).sort(function (left, right) {
        const leftActive = isActive(left);
        const rightActive = isActive(right);
        if (leftActive !== rightActive)
            return leftActive ? -1 : 1;
        const strengthDelta = (right.strength || 0) - (left.strength || 0);
        return strengthDelta !== 0 ? strengthDelta : Wifi.networkName(left).localeCompare(Wifi.networkName(right));
    })
    readonly property var detailAp: selectedNetwork() || ({})
    readonly property bool hasSelection: filteredNetworks.length > 0

    function startup() { if (windowHost.floatingMode) refresh(); }
    function clampIndex(index, length) { return Wifi.clampIndex(index, length); }
    function selectedNetwork() { return Wifi.selectedNetwork(filteredNetworks, selectedIndex); }
    function activeAccessPoint() { return Wifi.activeAccessPoint(activeStatus); }
    function networkName(ap) { return Wifi.networkName(ap); }
    function isActive(ap) { return Wifi.isActiveAccessPoint(ap, activeAccessPoint()); }
    function profileFor(ap) { return Wifi.profileForAccessPoint(ap, isActive(ap), activeStatus); }
    function autoconnectEnabled() { const profile = profileFor(detailAp); return !!(profile && profile.autoconnect); }
    function randomizedMacEnabled() { return !!Wifi.privacyFor(profileFor(detailAp)).randomized_mac; }
    function sendHostnameEnabled() { return Wifi.privacyFor(profileFor(detailAp)).send_hostname !== false; }
    function canEditProfile() { return !actionInFlight && !!profileFor(detailAp); }
    function canUsePrimaryAction() { return isActive(detailAp) ? !actionInFlight : canBeginConnectAction(detailAp); }
    function canShareSelected() { return shareAvailable && sharePayload.length > 0; }

    function resetShareAvailability() {
        shareAvailable = false;
        sharePayload = "";
        shareProfilePath = "";
        shareStatus = "Wi-Fi QR sharing is not available for this network.";
    }

    function refreshShareAvailability() {
        resetShareAvailability();
        if (!hasSelection)
            return;
        if (Wifi.canShareQr(detailAp))
            return setShareAvailability(true, Wifi.wifiQrPayload(detailAp), "Wi-Fi QR payload is ready.");
        const profile = profileFor(detailAp);
        if (!profile || !profile.path)
            return shareStatus = "Wi-Fi QR sharing requires an open network or a saved profile with a readable password.";
        if (sharing.running)
            return;
        shareProfilePath = profile.path;
        shareStatus = "Checking saved Wi-Fi password availability…";
        sharing.check(profile.path);
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
    function nowMs() { return new Date().getTime(); }
    function statusIsHeld() { return nowMs() < statusHoldUntil; }
    function setBackgroundStatus(message) { if (!statusIsHeld()) status = message; }
    function setHeldStatus(message, milliseconds) { status = message; statusHoldUntil = nowMs() + milliseconds; }
    function shareCheckAvailable(result) { return !!result.shareable && !!result.qr_payload; }
    function shareCheckPayload(result, available) { return available ? result.qr_payload : ""; }
    function shareCheckMessage(result, available) { return available ? "Wi-Fi QR payload is ready." : (result.reason || "Wi-Fi QR sharing is not available for this network."); }
    function applyShareCheckResult(result) {
        if (result.path !== shareProfilePath)
            return refreshShareAvailabilityIfOpen();
        const available = shareCheckAvailable(result);
        setShareAvailability(available, shareCheckPayload(result, available), shareCheckMessage(result, available));
    }
    function applyShareCheckOutput(output, errorText) { try { applyShareCheckResult(Wifi.apiData(JSON.parse(output), "payload")); } catch (error) { failShareCheck(errorText || error); } }
    function failShareCheck(error) { setShareAvailability(false, "", "Could not check Wi-Fi QR sharing: " + error); }

    function applyNetworks(newNetworks, resetSelection) {
        const previous = selectedNetwork();
        networks = newNetworks;
        selectedIndex = Wifi.selectedIndexAfterUpdate(previous, filteredNetworks, selectedIndex, resetSelection, isActive);
    }

    function refresh() {
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
    function maybeRunPendingRefresh() { if (pendingRefresh && !discovery.listRunning && !discovery.scanRunning) Qt.callLater(refresh); }
    function refreshStatus() { discovery.refreshStatus(); }

    function scanSnapshotStatus(event) { return event.networks_found + (event.scanning ? " networks found; scanning…" : " networks available"); }
    function scanCompleteStatus(event) { return event.networks_found + (event.timed_out ? " networks available; scan timed out" : " networks available"); }
    function scanEventStatus(event) {
        const message = event.message || status;
        const statuses = {
            snapshot: scanSnapshotStatus(event),
            complete: scanCompleteStatus(event),
            status: message,
            warning: message
        };
        return statuses[event.event] || status;
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

    function beginAction() {
        if (!actionInFlight)
            return true;
        status = "Wait for the current Wi-Fi action to finish…";
        return false;
    }
    function canBeginAnyConnectAction() { return !actions.nonConnectRunning; }
    function canBeginConnectAction(ap) { return canBeginAnyConnectAction() && Wifi.canStartConnection(ap); }
    function beginAnyConnectAction() {
        if (canBeginAnyConnectAction())
            return true;
        status = "Wait for the current Wi-Fi action to finish…";
        return false;
    }
    function beginConnectAction(ap) {
        if (canBeginConnectAction(ap))
            return true;
        status = "Wait for the current Wi-Fi action to finish…";
        return false;
    }
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
        if (Wifi.needsPassword(ap))
            return prompt.openPasswordPrompt(ap), true;
        if (Wifi.needsCredentials(ap))
            return prompt.openEnterpriseIdentityPrompt(ap), true;
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
        const request = { target: ap };
        if (password !== undefined && password !== null)
            request.password = password;
        return JSON.stringify(request);
    }
    function shouldAutoOpenPortal(ap, password) { return !!ap && ap.security === "--" && (password === undefined || password === null); }
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
        schedulePortalForConnect(ap, displayName, password);
        runConnect(Wifi.nmApiArgs("wifi", "connect-target"), displayName, connectTargetRequest(ap, password));
    }
    function runConnect(args, displayName, stdinText) {
        if (actions.nonConnectRunning) {
            status = "Wait for the current Wi-Fi action to finish…";
            return;
        }
        if (pendingPortalNetworkName !== displayName)
            pendingPortalNetworkName = "";
        status = actions.connectRunning ? "Switching connection attempt to " + displayName + "…" : "Connecting to " + displayName + "…";
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
        if (result.status === "error")
            status = message;
        else
            setHeldStatus(message, 2500);
        if (result.status !== "error" && result.suggest_open_portal)
            openPortal();
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
    function moveSelection(delta) { selectedIndex = clampIndex(selectedIndex + delta, filteredNetworks.length); }
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
    function handleSearchKey(event) {
        if (prompt.open)
            return;
        if (isEnterKey(event.key))
            return acceptKey(event, primarySelected);
        return handleBinding(event, [[Qt.Key_Escape, closeRequested], [Qt.Key_Down, focusNetworkListTop], [Qt.Key_Up, function () { moveSelection(-1); }], [Qt.Key_Right, openDetailsPane], [Qt.Key_Left, closeDetailsPane], [Qt.Key_F6, openHiddenNetworkPrompt], [Qt.Key_F5, refresh]]);
    }
    function handleDetailHotkey(event) {
        if (!detailsOpen)
            return false;
        const bindings = [
            [Qt.Key_C, canConnectDetail, connectSelected],
            [Qt.Key_D, canDisconnectDetail, disconnectSelected],
            [Qt.Key_F, canEditProfile, forgetSelected],
            [Qt.Key_I, function () { return hasSelection; }, openPortal],
            [Qt.Key_S, canShareSelected, shareSelected],
            [Qt.Key_A, canEditProfile, toggleAutoconnectSelected],
            [Qt.Key_R, canEditProfile, toggleRandomizedMacSelected],
            [Qt.Key_N, canEditProfile, toggleSendHostnameSelected]
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
        return handleBinding(event, [[Qt.Key_Escape, closeRequested], [Qt.Key_Down, function () { moveSelection(1); }], [Qt.Key_Up, function () { moveSelection(-1); }], [Qt.Key_Right, openDetailsPane], [Qt.Key_Left, closeDetailsPane], [Qt.Key_F6, openHiddenNetworkPrompt], [Qt.Key_F5, refresh]]);
    }

    onDetailsOpenChanged: {
        windowHost.requestPopoverReposition();
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
    WifiDiscoveryProcesses { id: discovery; controller: controller }
    WifiActionProcesses { id: actions; controller: controller }
    WifiShareProcess { id: sharing; controller: controller }
}
