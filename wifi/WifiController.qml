import Quickshell
import QtQuick
import "Wifi.js" as Wifi
import "NmApi.js" as NmApi
import "."

Item {
    id: controller

    required property var prompt
    required property var windowHost

    property alias networks: selection.networks
    property var activeStatus: null
    property var networkConnectivity: null
    property alias filterText: selection.filterText
    property alias selectedIndex: selection.selectedIndex
    property bool pendingRefresh: false
    property string status: "Loading Wi-Fi networks…"
    property string connectingNetworkName: ""
    property int connectingProgressTick: 0
    property bool scanSnapshotSeen: false
    property bool detailsOpen: false
    property real detailsExpansionProgress: 0
    property bool shareAvailable: false
    property string sharePayload: ""
    property string shareProfilePath: ""
    property string shareStatus: shareUnavailableMessage
    property double statusHoldUntil: 0
    property double portalOpenHoldUntil: 0
    property string pendingPortalNetworkName: ""
    property alias lastConnectAp: connectPolicy.lastConnectAp
    property string activeScanRequestId: ""
    property string activeConnectRequestId: ""

    readonly property bool uiActive: windowHost.uiActive
    readonly property int autoRefreshIntervalMs: 30000
    readonly property int scanWatchdogIntervalMs: 15000
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
    readonly property bool actionInFlight: backend.running
    readonly property bool connectRunning: backend.connectStarting || activeConnectRequestId.length > 0
    readonly property var filteredNetworks: selection.filteredNetworks
    readonly property var detailAp: selectedNetwork() || ({})
    readonly property bool hasSelection: filteredNetworks.length > 0
    readonly property string busyMessage: "Wait for the current Wi-Fi action to finish…"
    readonly property string shareUnavailableMessage: "Wi-Fi QR sharing is not available for this network."
    readonly property alias selectionModel: selection

    signal focusSearchRequested
    signal focusListTopRequested

    function startup() { if (windowHost.floatingMode) activateUi(); }
    function selectedNetwork() { return selection.selected(); }
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
        const result = Wifi.shareAvailability(detailAp, profileFor(detailAp), "Wi-Fi QR sharing requires an open network or a saved profile with a readable password.");
        if (result.state !== "check")
            return setShareAvailability(result.available, result.payload, result.message);
        if (backend.isPending("share"))
            return;
        shareProfilePath = result.profilePath;
        shareStatus = "Checking saved Wi-Fi password availability…";
        backend.share(result.profilePath);
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
    function secretStale(ap) { return connectPolicy.secretStale(ap); }
    function markSecretStale(ap) { connectPolicy.markSecretStale(ap); }
    function clearSecretStale(ap) { connectPolicy.clearSecretStale(ap); }
    function blockLastConnectRetry(milliseconds) { connectPolicy.blockLastConnectRetry(milliseconds); }
    function retryDelayRemainingMs(ap, password) { return connectPolicy.retryDelayRemainingMs(ap, password); }
    function rememberConnectAttempt(ap, password) { connectPolicy.rememberConnectAttempt(ap, password); }
    function statusIsHeld() { return nowMs() < statusHoldUntil; }
    function setBackgroundStatus(message) { if (!statusIsHeld()) status = message; }
    function setHeldStatus(message, milliseconds) { status = message; statusHoldUntil = nowMs() + milliseconds; }
    function applyShareResponse(response, errorText) {
        try {
            const result = Wifi.shareCheckAvailability(Wifi.apiData(response, "result"), shareUnavailableMessage);
            if (result.path !== shareProfilePath)
                return refreshShareAvailabilityIfOpen();
            setShareAvailability(result.available, result.payload, result.message);
        } catch (error) {
            setShareAvailability(false, "", "Could not check Wi-Fi QR sharing: " + (errorText || error));
        }
    }

    function applyNetworks(newNetworks, resetSelection) {
        selection.apply(newNetworks, resetSelection);
    }

    function activateUi() {
        if (!uiActive)
            return;
        refresh();
        autoRefreshTimer.restart();
        if (connectRunning)
            connectingProgressTimer.restart();
    }

    function deactivateUi() {
        pendingRefresh = false;
        backend.cancel(activeScanRequestId);
        activeScanRequestId = "";
        scanSnapshotSeen = false;
        autoRefreshTimer.stop();
        if (!connectRunning)
            connectingProgressTimer.stop();
    }

    function refresh() {
        if (!uiActive) {
            pendingRefresh = false;
            return;
        }
        if (connectRunning) {
            pendingRefresh = true;
            setBackgroundStatus("Connection in progress; delaying Wi-Fi scan refresh…");
            return;
        }
        if (backend.listRunning || backend.scanRunning) {
            pendingRefresh = true;
            status = "Refresh already running; queued another refresh…";
            return;
        }
        pendingRefresh = false;
        setBackgroundStatus("Loading cached Wi-Fi networks…");
        scanSnapshotSeen = false;
        backend.refreshNetworks(false);
        backend.startScan();
    }
    function maybeRunPendingRefresh() { if (uiActive && pendingRefresh && !connectRunning && !backend.listRunning && !backend.scanRunning) Qt.callLater(refresh); }

    function handleScanWatchdog() {
        if (!uiActive || activeScanRequestId.length === 0)
            return;
        backend.cancel(activeScanRequestId);
        activeScanRequestId = "";
        if (!scanSnapshotSeen) {
            status = "Wi-Fi scan events timed out; loading refreshed cache…";
            if (!backend.listRunning)
                backend.refreshNetworks(false);
        } else {
            setBackgroundStatus("Wi-Fi scan finished without a completion event.");
        }
        maybeRunPendingRefresh();
    }

    function applyScanEvent(event) {
        if (event.event === "snapshot") {
            scanSnapshotSeen = true;
            applyNetworks(event.networks || [], false);
        }
        setBackgroundStatus(Wifi.scanEventStatus(event, status));
    }

    function finishConnectEvent(event, succeeded) {
        activeConnectRequestId = "";
        resetConnectProgress();
        applyConnectResult(Wifi.connectEventResult(event), event.message || (succeeded ? "Connected" : "Connection failed"));
        if (succeeded)
            refresh();
    }

    function handleConnectEvent(event) {
        if (!Wifi.requestMatches(event, activeConnectRequestId))
            return;
        const state = Wifi.connectEventState(event);
        if (state === "progress")
            return setBackgroundStatus(event.message || "Connecting to " + connectingNetworkName + "…");
        finishConnectEvent(event, state === "succeeded");
    }

    function handleSecretEvent(event) {
        if (event.event === "requested") {
            prompt.openDaemonSecretPrompt(event);
            return;
        }
        if (event.event === "cancelled" && prompt.mode === "daemon-secret" && prompt.secretRequestId === event.request_id) {
            prompt.cancel();
            status = "NetworkManager cancelled the Wi-Fi secret request.";
            return;
        }
        if (event.event === "persistence")
            status = event.status === "stored" ? "Wi-Fi secret saved to the keyring." : "Wi-Fi secret was accepted but could not be saved: " + event.status;
    }

    function handleScanStreamEvent(event) {
        if (!uiActive || !Wifi.requestMatches(event, activeScanRequestId))
            return;
        applyScanEvent(event);
        if (Wifi.isTerminalEvent(event)) {
            activeScanRequestId = "";
            maybeRunPendingRefresh();
        }
    }

    function applyStatusEvent(event) {
        if (event.event !== "changed")
            return;
        activeStatus = event.status || null;
        applyNetworks(networks, false);
        refreshShareAvailabilityIfOpen();
    }

    function applyConnectivityEvent(event) {
        if (event.event === "changed")
            networkConnectivity = event.connectivity || null;
    }

    function handleDaemonEvent(event) {
        try {
            Wifi.requireApiEvent(event);
            const handlers = ({});
            handlers[NmApi.streams.wifi_status] = applyStatusEvent;
            handlers[NmApi.streams.network_connectivity] = applyConnectivityEvent;
            handlers[NmApi.streams.wifi_scan] = handleScanStreamEvent;
            handlers[NmApi.streams.wifi_connect] = handleConnectEvent;
            handlers[NmApi.streams.wifi_secret] = handleSecretEvent;
            if (handlers[event.stream])
                handlers[event.stream](event);
        } catch (error) {
            status = "Could not parse nm-daemon event: " + error;
        }
    }

    function failCall(id, message) {
        if (id === "connect-start")
            resetConnectProgress();
        status = message;
        maybeRunPendingRefresh();
    }

    function requireIdle(ready) {
        if (!ready)
            status = busyMessage;
        return ready;
    }
    function beginAction() { return requireIdle(!actionInFlight); }
    function canBeginAnyConnectAction() { return !backend.running; }
    function canBeginConnectAction(ap) { return canBeginAnyConnectAction() && Wifi.canStartConnection(ap); }
    function beginAnyConnectAction() { return requireIdle(canBeginAnyConnectAction()); }
    function beginConnectAction(ap) { return requireIdle(canBeginConnectAction(ap)); }
    function primarySelected() { return isActive(selectedNetwork()) ? disconnectSelected() : connectSelected(); }
    function isConnecting(ap) { return connectRunning && connectingNetworkName.length > 0 && Wifi.networkName(ap) === connectingNetworkName && !isActive(ap); }
    function connectingNetworkIsActive() { return connectingNetworkName.length > 0 && Wifi.networkName(activeAccessPoint()) === connectingNetworkName; }
    function updateVisibleConnectProgress() {
        if (!connectRunning || !connectingNetworkIsActive())
            return;
        setHeldStatus("Connected to " + connectingNetworkName, 2500);
        openPendingPortal();
        connectingProgressTimer.stop();
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
        return request;
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
        if (connectRunning && connectPolicy.lastConnectAttemptKey === attemptKey && connectPolicy.lastConnectSecretFingerprint === secretFingerprint) {
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
        runConnect(connectTargetRequest(ap, password), displayName);
    }
    function runConnect(request, displayName) {
        if (!requireIdle(!backend.nonConnectRunning))
            return;
        if (pendingPortalNetworkName !== displayName)
            pendingPortalNetworkName = "";
        status = connectRunning ? "Connection attempt already running…" : "Connecting to " + displayName + "…";
        connectingNetworkName = displayName;
        connectingProgressTick = 0;
        connectingProgressTimer.restart();
        backend.connect(request);
    }
    function resetConnectProgress() { connectingNetworkName = ""; connectingProgressTick = 0; connectingProgressTimer.stop(); }
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
    function provideSecret(requestId, key, password, save) {
        status = "Sending requested Wi-Fi secret to NetworkManager…";
        backend.provideSecret(requestId, key, password, save);
    }
    function cancelSecret(requestId) { backend.cancelSecret(requestId); }
    function disconnectSelected() {
        if (!beginAction())
            return;
        status = "Disconnecting Wi-Fi…";
        backend.disconnect();
    }
    function runProfileAction(action) {
        if (!beginAction())
            return;
        const profile = profileFor(selectedNetwork());
        if (profile)
            action(profile);
    }
    function forgetSelected() { runProfileAction(function (profile) { status = "Forgetting saved profile " + profile.id + "…"; backend.profile({ operation: "delete", path: profile.path }); }); }
    function toggleAutoconnectSelected() { runProfileAction(function (profile) { const enabled = !profile.autoconnect; status = (enabled ? "Enabling" : "Disabling") + " autoconnect for " + profile.id + "…"; backend.profile({ operation: "set-autoconnect", path: profile.path, enabled: enabled }); }); }
    function setMacRandomizedSelected(enabled) { runProfileAction(function (profile) { status = (enabled ? "Using randomized MAC for " : "Using device MAC for ") + profile.id + "…"; backend.profile({ operation: "set-mac-randomization", path: profile.path, randomized: enabled }); }); }
    function toggleSendHostnameSelected() { runProfileAction(function (profile) { const enabled = !(profile.privacy && profile.privacy.send_hostname !== false); status = (enabled ? "Sending" : "Hiding") + " device name for " + profile.id + "…"; backend.profile({ operation: "set-send-hostname", path: profile.path, enabled: enabled }); }); }
    function openPortal() {
        if (nowMs() < portalOpenHoldUntil)
            return;
        portalOpenHoldUntil = nowMs() + 12000;
        status = "Opening captive portal page…";
        backend.openPortal();
    }
    function canConnectDetail() { return !isActive(detailAp) && canUsePrimaryAction(); }
    function canDisconnectDetail() { return isActive(detailAp) && canUsePrimaryAction(); }
    function toggleRandomizedMacSelected() { setMacRandomizedSelected(!randomizedMacEnabled()); }

    function toggleDetailsPane() { navigation.toggleDetails(); }
    function focusSearchBox() { navigation.focusSearch(); }
    function closeRequested() { windowHost.closeRequested(); }
    function openHiddenNetworkPrompt() { if (beginAnyConnectAction()) prompt.openHiddenNetworkPrompt(); }
    function handleSearchKey(event) { navigation.handleSearchKey(event); }
    function handleListKey(event) { navigation.handleListKey(event); }

    onDetailsOpenChanged: {
        if (detailsOpen) {
            Qt.callLater(refreshShareAvailability);
        }
    }
    onSelectedIndexChanged: if (detailsOpen) Qt.callLater(refreshShareAvailability)
    onActiveStatusChanged: updateVisibleConnectProgress()
    onActiveScanRequestIdChanged: activeScanRequestId.length > 0 ? scanWatchdogTimer.restart() : scanWatchdogTimer.stop()

    Connections { target: prompt; function onOpenChanged() { if (!prompt.open) Qt.callLater(focusSearchBox); } }
    Behavior on detailsExpansionProgress {
        enabled: !controller.windowHost.noAnimations
        NumberAnimation {
            duration: 220
            easing.type: Easing.InOutSine
        }
    }
    Timer { id: connectingProgressTimer; interval: 120; repeat: true; onTriggered: controller.connectingProgressTick += 1 }
    Timer { id: captivePortalOpenTimer; interval: 2500; repeat: false; onTriggered: controller.openPendingPortal() }
    Timer { id: scanWatchdogTimer; interval: controller.scanWatchdogIntervalMs; repeat: false; onTriggered: controller.handleScanWatchdog() }
    Timer { id: autoRefreshTimer; interval: controller.autoRefreshIntervalMs; repeat: true; onTriggered: controller.refresh() }
    WifiSelectionModel { id: selection; activeAccessPoint: controller.activeAccessPoint() }
    WifiConnectPolicy { id: connectPolicy }
    WifiNavigation { id: navigation; controller: controller }
    WifiBackend { id: backend; controller: controller }
}
