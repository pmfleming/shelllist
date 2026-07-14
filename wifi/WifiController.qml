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
    property string connectWorkspaceId: ""
    property alias lastConnectAp: connectPolicyModel.lastConnectAp
    property string activeScanRequestId: ""
    property string activeConnectRequestId: ""

    readonly property bool uiActive: windowHost.uiActive
    readonly property int autoRefreshIntervalMs: 30000
    readonly property int scanWatchdogIntervalMs: 15000
    readonly property int closedWindowWidth: 453
    readonly property int contentMargin: 14
    readonly property int listPaneWidth: closedWindowWidth - 2 * contentMargin
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
    readonly property var detailAp: selection.selected() || ({})
    readonly property bool hasSelection: filteredNetworks.length > 0
    readonly property string busyMessage: "Wait for the current Wi-Fi action to finish…"
    readonly property string shareUnavailableMessage: "Wi-Fi QR sharing is not available for this network."
    readonly property alias selectionModel: selection
    readonly property alias connectPolicy: connectPolicyModel
    readonly property alias navigation: navigationModel
    readonly property alias detailActions: detailActionModel.actions

    signal focusSearchRequested
    signal focusListTopRequested

    function startup() { if (windowHost.floatingMode) activateUi(); }
    function activeAccessPoint() { return activeStatus ? (activeStatus.access_point || activeStatus.network || null) : null; }
    function networkName(ap) { return Wifi.networkName(ap); }
    function isActive(ap) { return !!(ap && ap.active); }
    function profileFor(ap) { return Wifi.profileForAccessPoint(ap); }
    function autoconnectEnabled() { const profile = profileFor(detailAp); return !!(profile && profile.autoconnect); }
    function randomizedMacEnabled() { return !!Wifi.privacyFor(profileFor(detailAp)).randomized_mac; }
    function sendHostnameEnabled() { return Wifi.privacyFor(profileFor(detailAp)).send_hostname !== false; }
    function canProfileAction(capability) { const caps = detailAp.capabilities || ({}); return !actionInFlight && !!profileFor(detailAp) && caps[capability] === true; }
    function canForgetProfile() { const caps = detailAp.capabilities || ({}); return !actionInFlight && (isActive(detailAp) || caps.can_forget === true); }
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
            selection.apply(event.networks || [], false);
        }
        setBackgroundStatus(Wifi.scanEventStatus(event, status));
    }

    function finishConnectEvent(event, succeeded) {
        const requestId = event.request_id || activeConnectRequestId;
        activeConnectRequestId = "";
        resetConnectProgress();
        applyConnectResult(Wifi.connectEventResult(event), event.message || (succeeded ? "Connected" : "Connection failed"), requestId);
        if (succeeded)
            refresh();
    }

    function handleConnectEvent(event) {
        if (!Wifi.requestMatches(event, activeConnectRequestId))
            return;
        if (event.event === "cancelled") {
            activeConnectRequestId = "";
            resetConnectProgress();
            setHeldStatus(event.message || "Connection cancelled", 2500);
            refresh();
            return;
        }
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
    function primarySelected() { return connectRunning ? cancelConnection() : (isActive(selection.selected()) ? disconnectSelected() : connectSelected()); }
    function isConnecting(ap) { return connectRunning && connectingNetworkName.length > 0 && Wifi.networkName(ap) === connectingNetworkName && !isActive(ap); }
    function connectingNetworkIsActive() { return connectingNetworkName.length > 0 && Wifi.networkName(activeAccessPoint()) === connectingNetworkName; }
    function updateVisibleConnectProgress() {
        if (!connectRunning || !connectingNetworkIsActive())
            return;
        setHeldStatus("Connected to " + connectingNetworkName, 2500);
        connectingProgressTimer.stop();
    }
    function deferConnectForPrompt(ap) {
        if (connectPolicyModel.secretStale(ap)) {
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
        const ap = selection.selected();
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
    function runConnectTarget(ap, displayName, password) {
        const attemptKey = Wifi.connectAttemptKey(ap);
        const secretFingerprint = Wifi.passwordFingerprint(password);
        if (connectRunning && connectPolicy.lastConnectAttemptKey === attemptKey && connectPolicy.lastConnectSecretFingerprint === secretFingerprint) {
            status = "Connection attempt for " + displayName + " is already running…";
            return;
        }
        const retryDelay = connectPolicyModel.retryDelayRemainingMs(ap, password);
        if (retryDelay > 0) {
            status = "Waiting " + Math.ceil(retryDelay / 1000) + "s before retrying " + displayName + "; NetworkManager is temporarily ignoring this AP.";
            return;
        }
        connectPolicyModel.rememberConnectAttempt(ap, password);
        runConnect(connectTargetRequest(ap, password), displayName);
    }
    function runConnect(request, displayName) {
        if (!requireIdle(!backend.nonConnectRunning))
            return;
        status = connectRunning ? "Connection attempt already running…" : "Connecting to " + displayName + "…";
        connectingNetworkName = displayName;
        connectWorkspaceId = windowHost.shelllistWorkspaceId();
        connectingProgressTick = 0;
        connectingProgressTimer.restart();
        backend.connect(request);
    }
    function resetConnectProgress() { connectingNetworkName = ""; connectingProgressTick = 0; connectingProgressTimer.stop(); }
    function applyConnectResult(result, fallbackText, requestId) {
        const message = Wifi.connectResultMessage(result, fallbackText);
        if (result.status === "error") {
            status = message;
            if (Wifi.isSecretFailureReason(result.reason)) {
                connectPolicyModel.markSecretStale(lastConnectAp);
                connectPolicyModel.blockLastConnectRetry(Wifi.connectFailureRetryMs(result.reason));
                if (lastConnectAp)
                    prompt.openPasswordPrompt(lastConnectAp, Wifi.isWrongPasswordReason(result.reason) ? "Wrong password. Enter a new Wi-Fi password." : "Saved password failed. Enter a new Wi-Fi password.");
            }
        } else {
            connectPolicyModel.clearSecretStale(lastConnectAp);
            setHeldStatus(message, 2500);
        }
        if (Wifi.confirmedPortalResult(result))
            openConfirmedPortal(result, requestId || "");
        maybeRunPendingRefresh();
    }

    function portalContext(trigger, ap, result, requestId, workspaceId, automatic, fallback) {
        const connectivity = result && result.connectivity ? result.connectivity : (networkConnectivity || (activeStatus && activeStatus.connectivity) || ({}));
        const identity = Wifi.portalNetworkIdentity(ap, result || ({}));
        const episode = automatic ? identity + "::" + requestId : "";
        return {
            trigger: trigger,
            ssid: result && result.ssid ? result.ssid : Wifi.networkName(ap),
            identity: identity,
            episode: episode,
            connectivity: connectivity.state || "unknown",
            requestId: requestId,
            workspaceId: workspaceId,
            automatic: automatic,
            fallback: fallback
        };
    }

    function launchPortal(context) {
        console.info("shelllist portal trigger=" + context.trigger
            + " ssid=" + context.ssid
            + " identity=" + context.identity
            + " connectivity=" + context.connectivity
            + " request_id=" + context.requestId
            + " workspace=" + context.workspaceId);
        status = "Opening captive portal page…";
        backend.openPortal(context);
    }

    function openConfirmedPortal(result, requestId) {
        launchPortal(portalContext("connect-result", lastConnectAp, result, requestId, connectWorkspaceId, true, false));
    }
    function provideSecret(requestId, key, password, save) {
        status = "Sending requested Wi-Fi secret to NetworkManager…";
        backend.provideSecret(requestId, key, password, save);
    }
    function cancelSecret(requestId) { backend.cancelSecret(requestId); }
    function cancelConnection() {
        if (activeConnectRequestId.length === 0)
            return status = "Waiting for the connection request to become cancellable…";
        status = "Cancelling connection to " + connectingNetworkName + "…";
        backend.cancel(activeConnectRequestId);
    }
    function disconnectSelected() {
        if (!beginAction())
            return;
        status = "Disconnecting Wi-Fi…";
        backend.disconnect();
    }
    function runProfileAction(action) {
        if (!beginAction())
            return;
        const profile = profileFor(selection.selected());
        if (profile)
            action(profile);
    }
    function forgetSelected() {
        if (!canForgetProfile())
            return status = busyMessage;
        const profiles = detailAp.profiles && detailAp.profiles.length > 0 ? detailAp.profiles : (profileFor(detailAp) ? [profileFor(detailAp)] : []);
        prompt.openForgetPrompt(detailAp, isActive(detailAp), profiles);
    }
    function executeForget(ap) {
        if (!beginAction())
            return;
        const requestId = "forget-" + Math.round(nowMs());
        status = (isActive(ap) ? "Disconnecting and forgetting " : "Forgetting ") + Wifi.networkName(ap) + "…";
        backend.profile({ operation: "forget", request_id: requestId, target: Wifi.connectTarget(ap) });
    }
    function toggleAutoconnectSelected() { runProfileAction(function (profile) { const enabled = !profile.autoconnect; status = (enabled ? "Enabling" : "Disabling") + " autoconnect for " + profile.id + "…"; backend.profile({ operation: "set-autoconnect", path: profile.path, enabled: enabled }); }); }
    function setMacRandomizedSelected(enabled) { runProfileAction(function (profile) { status = (enabled ? "Using randomized MAC for " : "Using device MAC for ") + profile.id + "…"; backend.profile({ operation: "set-mac-randomization", path: profile.path, randomized: enabled }); }); }
    function toggleSendHostnameSelected() { runProfileAction(function (profile) { const enabled = !(profile.privacy && profile.privacy.send_hostname !== false); status = (enabled ? "Sending" : "Hiding") + " device name for " + profile.id + "…"; backend.profile({ operation: "set-send-hostname", path: profile.path, enabled: enabled }); }); }
    function openPortal() {
        launchPortal(portalContext("manual", detailAp, null, "", windowHost.shelllistWorkspaceId(), false, false));
    }
    function triggerDetailAction(id) { detailActionModel.trigger(id); }
    function canConnectDetail() { return !isActive(detailAp) && canUsePrimaryAction(); }
    function canDisconnectDetail() { return isActive(detailAp) && canUsePrimaryAction(); }
    function toggleRandomizedMacSelected() { setMacRandomizedSelected(!randomizedMacEnabled()); }

    function openHiddenNetworkPrompt() { if (beginAnyConnectAction()) prompt.openHiddenNetworkPrompt(); }

    onDetailsOpenChanged: {
        if (detailsOpen) {
            Qt.callLater(refreshShareAvailability);
        }
    }
    onSelectedIndexChanged: if (detailsOpen) Qt.callLater(refreshShareAvailability)
    onActiveStatusChanged: updateVisibleConnectProgress()
    onActiveScanRequestIdChanged: activeScanRequestId.length > 0 ? scanWatchdogTimer.restart() : scanWatchdogTimer.stop()

    Connections { target: prompt; function onOpenChanged() { if (!prompt.open) Qt.callLater(navigationModel.focusSearch); } }
    Behavior on detailsExpansionProgress {
        enabled: !controller.windowHost.noAnimations
        NumberAnimation {
            duration: 220
            easing.type: Easing.InOutSine
        }
    }
    Timer { id: connectingProgressTimer; interval: 120; repeat: true; onTriggered: controller.connectingProgressTick += 1 }
    Timer { id: scanWatchdogTimer; interval: controller.scanWatchdogIntervalMs; repeat: false; onTriggered: controller.handleScanWatchdog() }
    Timer { id: autoRefreshTimer; interval: controller.autoRefreshIntervalMs; repeat: true; onTriggered: controller.refresh() }
    WifiSelectionModel { id: selection }
    WifiConnectPolicy { id: connectPolicyModel }
    WifiDetailActions { id: detailActionModel; controller: controller }
    WifiNavigation { id: navigationModel; controller: controller }
    WifiBackend { id: backend; controller: controller }
}
