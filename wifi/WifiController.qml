import QtQuick
import "WifiPresentation.js" as Presentation
import "WifiFlow.js" as Flow
import "NmApiClient.js" as Api
import "NmApi.js" as NmApi
import "core" as Core
import "."

Item {
    id: wifi

    required property WifiPromptController prompt

    property bool uiActive
    property string currentWorkspaceId

    property var activeStatus: null
    property var networkConnectivity: null
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    property bool pendingRefresh: false
    property string status: "Loading Wi-Fi networks…"
    property string connectingNetworkName: ""
    property int connectingProgressTick: 0
    property bool scanSnapshotSeen: false
    property bool detailsOpen: false
    property real detailsExpansionProgress: 0
    property bool advancedOpen: false
    property string advancedSection: "security"
    property string advancedProfilePath: ""
    property var advancedProfile: ({})
    property string advancedSecret: ""
    property string advancedError: ""
    property string advancedSaveOrigin: ""
    property double statusHoldUntil: 0
    property string connectWorkspaceId: ""
    property string activeScanRequestId: ""
    property string activeConnectRequestId: ""

    readonly property int autoRefreshIntervalMs: 30000
    readonly property int scanWatchdogIntervalMs: 15000
    readonly property int closedWindowWidth: 453
    readonly property int contentMargin: 14
    readonly property int contentVerticalMargin: 24
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
    readonly property bool advancedLoading: backend.isPending("advanced-load")
    readonly property bool advancedSaving: backend.isPending("advanced-save")
    readonly property bool advancedSecretLoading: backend.isPending("advanced-secret")
    readonly property string detailsTab: advancedOpen ? advancedSection : "network"
    readonly property bool scanInFlight: backend.listRunning || backend.scanRunning
    readonly property bool connectRunning: backend.connectStarting || activeConnectRequestId.length > 0
    readonly property var filteredResults: results.visibleResults
    readonly property var detailResult: results.selected()
    readonly property var detailAp: detailResult ? detailResult.payload : ({})
    readonly property bool hasSelection: filteredResults.length > 0
    readonly property string busyMessage: "Wait for the current Wi-Fi action to finish…"
    readonly property alias shareAvailable: shareModel.available
    readonly property alias sharePayload: shareModel.payload
    readonly property alias shareStatus: shareModel.status
    readonly property alias shareUnavailableMessage: shareModel.unavailableMessage
    readonly property alias shareController: shareModel
    readonly property alias selectionModel: results
    readonly property alias providerModel: wifiProviderModel
    readonly property alias providerRegistry: providers
    readonly property alias connectPolicy: connectPolicyModel
    readonly property alias navigation: navigationModel
    readonly property var detailActions: providers.actionsFor(detailResult)
    readonly property var daemonEventHandlerByStream: {
        const handlers = ({});
        handlers[NmApi.streams.wifi_status] = function (event) { wifi.applyStatusEvent(event); };
        handlers[NmApi.streams.network_connectivity] = function (event) { wifi.applyConnectivityEvent(event); };
        handlers[NmApi.streams.wifi_scan] = function (event) { wifi.handleScanStreamEvent(event); };
        handlers[NmApi.streams.wifi_connect] = function (event) { wifi.handleConnectEvent(event); };
        handlers[NmApi.streams.wifi_secret] = function (event) { wifi.handleSecretEvent(event); };
        return handlers;
    }

    signal focusSearchRequested
    signal focusListTopRequested
    signal advancedSectionLeaving(string section)
    signal windowPlacementRequested
    signal closeWindowRequested

    function startup(floatingMode, workspaceId) {
        if (floatingMode)
            activateUi(workspaceId);
    }
    function activeAccessPoint() { return activeStatus ? (activeStatus.access_point || activeStatus.network || null) : null; }
    function networkName(ap) { return Presentation.networkName(ap); }
    function isActive(ap) { return !!(ap && ap.active); }
    function profileFor(ap) { return Flow.profileForAccessPoint(ap); }
    function autoconnectEnabledFor(ap) { const profile = profileFor(ap); return !!(profile && profile.autoconnect); }
    function randomizedMacEnabledFor(ap) { return !!Presentation.privacyFor(profileFor(ap)).randomized_mac; }
    function sendHostnameEnabledFor(ap) { return Presentation.privacyFor(profileFor(ap)).send_hostname !== false; }
    function canProfileActionFor(ap, capability) { const caps = ap && ap.capabilities ? ap.capabilities : ({}); return !actionInFlight && !!profileFor(ap) && caps[capability] === true; }
    function canForgetNetwork(ap) { const caps = ap && ap.capabilities ? ap.capabilities : ({}); return !actionInFlight && (isActive(ap) || caps.can_forget === true); }
    function canConnectNetwork(ap) { return !isActive(ap) && canBeginConnectAction(ap); }
    function canDisconnectNetwork(ap) { return isActive(ap) && !actionInFlight; }
    function canShareNetwork(ap) { return !!ap && !!detailAp && ap.key === detailAp.key && shareModel.canShareSelected(); }

    function selectDetailsTab(tab) {
        if (tab === "network") {
            closeAdvancedSettings();
            return;
        }
        if (advancedOpen && tab !== advancedSection)
            advancedSectionLeaving(advancedSection);
        openAdvancedSettings(tab);
    }

    function cycleDetailsTab() {
        if (!detailsOpen)
            return;
        const tabs = profileFor(detailAp) ? ["network", "security", "hardware"] : ["network"];
        const index = Math.max(0, tabs.indexOf(detailsTab));
        selectDetailsTab(tabs[(index + 1) % tabs.length]);
    }

    function openAdvancedSettings(section) {
        const profile = profileFor(detailAp);
        if (!profile)
            return status = "Connect to this network before editing saved settings.";
        detailsOpen = true;
        detailsExpansionProgress = 1;
        windowPlacementRequested();
        advancedSection = section === "hardware" ? "hardware" : "security";
        if (advancedOpen && advancedProfilePath === (profile.path || ""))
            return;
        advancedOpen = true;
        advancedProfilePath = profile.path || "";
        advancedProfile = ({});
        advancedSecret = "";
        advancedError = "";
        if (!backend.loadAdvancedProfile(advancedProfilePath))
            advancedError = "Saved profile details are already loading.";
    }

    function closeAdvancedSettings() {
        if (advancedOpen)
            advancedSectionLeaving(advancedSection);
        advancedOpen = false;
        advancedProfilePath = "";
        advancedProfile = ({});
        advancedSecret = "";
        advancedError = "";
    }

    function applyAdvancedProfile(profile) {
        if (!advancedOpen || (profile.path || "") !== advancedProfilePath)
            return;
        advancedProfile = profile;
        advancedError = "";
    }

    function saveAdvancedSettings(settings, origin) {
        if (!advancedOpen || advancedProfilePath.length === 0 || advancedSaving)
            return false;
        advancedError = "";
        advancedSaveOrigin = origin || advancedSection;
        if (!backend.saveAdvancedProfile(advancedProfilePath, settings)) {
            advancedSaveOrigin = "";
            advancedError = "Advanced profile settings are already being saved.";
            return false;
        }
        return true;
    }

    function applyAdvancedSave(result) {
        const origin = advancedSaveOrigin;
        advancedSaveOrigin = "";
        status = result.message || "Saved advanced Wi-Fi settings";
        advancedSecret = "";
        if (advancedOpen && advancedProfilePath.length > 0 && advancedSection === origin)
            backend.loadAdvancedProfile(advancedProfilePath);
    }

    function revealAdvancedSecret() {
        if (!advancedOpen || advancedProfilePath.length === 0 || advancedSecretLoading)
            return;
        advancedError = "";
        backend.revealAdvancedSecret(advancedProfilePath);
    }

    function applyAdvancedSecret(result) {
        if (!advancedOpen || (result.path || "") !== advancedProfilePath)
            return;
        advancedSecret = result.available ? (result.password || "") : "";
        advancedError = result.available ? "" : "The saved Wi-Fi password is not readable.";
    }

    function invalidateShareAvailabilityCache() { shareModel.invalidate(); }
    function refreshShareAvailability() { shareModel.refresh(); }
    function shareSelected() { shareModel.copySelected(); }
    function applyShareResponse(response, errorText) { shareModel.applyResponse(response, errorText); }
    function statusIsHeld() { return Date.now() < statusHoldUntil; }
    function setBackgroundStatus(message) { if (!statusIsHeld()) status = message; }
    function setHeldStatus(message, milliseconds) { status = message; statusHoldUntil = Date.now() + milliseconds; }

    function activateUi(workspaceId) {
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
        refresh();
        autoRefreshTimer.restart();
        if (connectRunning)
            connectingProgressTimer.restart();
    }

    function deactivateUi() {
        uiActive = false;
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
        setBackgroundStatus(Api.scanEventStatus(event, status));
    }

    function finishConnectEvent(event, succeeded) {
        const requestId = event.request_id || activeConnectRequestId;
        activeConnectRequestId = "";
        resetConnectProgress();
        applyConnectResult(Api.connectEventResult(event), event.message || (succeeded ? "Connected" : "Connection failed"), requestId);
        if (succeeded)
            refresh();
    }

    function handleConnectEvent(event) {
        if (!Api.requestMatches(event, activeConnectRequestId))
            return;
        if (event.event === "cancelled") {
            activeConnectRequestId = "";
            resetConnectProgress();
            setHeldStatus(event.message || "Connection cancelled", 2500);
            refresh();
            return;
        }
        const state = Api.connectEventState(event);
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
        if (!uiActive || !Api.requestMatches(event, activeScanRequestId))
            return;
        applyScanEvent(event);
        if (Api.isTerminalEvent(event)) {
            activeScanRequestId = "";
            maybeRunPendingRefresh();
        }
    }

    function applyStatusEvent(event) {
        if (event.event !== "changed")
            return;
        activeStatus = event.status || null;
    }

    function applyConnectivityEvent(event) {
        if (event.event !== "changed")
            return;
        const previous = networkConnectivity;
        networkConnectivity = event.connectivity || null;
        if (previous && Presentation.connectivityRequiresSignIn(previous)
                && networkConnectivity && (networkConnectivity.full || networkConnectivity.state === "full")) {
            const active = activeAccessPoint();
            setHeldStatus("Connected to " + (active ? Presentation.networkName(active) : "Wi-Fi") + " with internet access", 2500);
        }
    }

    function handleDaemonEvent(event) {
        try {
            Api.requireApiEvent(event);
            const handler = daemonEventHandlerByStream[event.stream];
            if (handler)
                handler(event);
        } catch (error) {
            status = "Could not parse nm-daemon event: " + error;
        }
    }

    function failCall(id, message) {
        if (id === "connect-start")
            resetConnectProgress();
        if (id === "advanced-load" || id === "advanced-save" || id === "advanced-secret")
            advancedError = message;
        if (id === "advanced-save")
            advancedSaveOrigin = "";
        if (id === "share")
            shareModel.fail(message);
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
    function canBeginConnectAction(ap) { return canBeginAnyConnectAction() && !!(ap && ap.capabilities && ap.capabilities.can_connect); }
    function beginAnyConnectAction() { return requireIdle(canBeginAnyConnectAction()); }
    function beginConnectAction(ap) { return requireIdle(canBeginConnectAction(ap)); }
    function primarySelected() { return providers.execute(detailResult, "", { workspaceId: currentWorkspaceId }); }
    function isConnecting(ap) { return connectRunning && connectingNetworkName.length > 0 && Presentation.networkName(ap) === connectingNetworkName && !isActive(ap); }
    function connectingNetworkIsActive() { return connectingNetworkName.length > 0 && Presentation.networkName(activeAccessPoint()) === connectingNetworkName; }
    function updateVisibleConnectProgress() {
        if (!connectRunning || !connectingNetworkIsActive())
            return;
        setHeldStatus("Wi-Fi link established with " + connectingNetworkName + "; checking internet access…", 2500);
        connectingProgressTimer.stop();
    }
    function deferConnectForPrompt(ap) {
        if (connectPolicyModel.secretStale(ap)) {
            prompt.openPasswordPrompt(ap, "Saved password failed. Enter a new Wi-Fi password.");
            return true;
        }
        const promptKind = ap && ap.connect_prompt ? (ap.connect_prompt.kind || "none") : "none";
        if (promptKind === "password") {
            prompt.openPasswordPrompt(ap);
            return true;
        }
        if (promptKind === "enterprise") {
            prompt.openEnterpriseIdentityPrompt(ap);
            return true;
        }
        if (ap && ap.capabilities && ap.capabilities.can_connect)
            return false;
        status = "This access point cannot be connected from Shelllist yet. Use F6 for hidden SSIDs.";
        return true;
    }
    function connectNetwork(ap) {
        if (!ap || !beginConnectAction(ap))
            return false;
        if (!deferConnectForPrompt(ap))
            runConnectTarget(ap, Presentation.networkName(ap));
        return true;
    }
    function connectTargetRequest(ap, password, enterpriseIdentity) {
        const request = ap.key ? { key: ap.key } : { target: ap };
        if (password !== undefined && password !== null)
            request.password = password;
        if (enterpriseIdentity)
            request.enterprise_identity = enterpriseIdentity;
        return request;
    }
    function runConnectTarget(ap, displayName, password, enterpriseIdentity) {
        const attemptKey = Flow.connectAttemptKey(ap);
        const secretFingerprint = Flow.passwordFingerprint(password);
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
        runConnect(connectTargetRequest(ap, password, enterpriseIdentity), displayName);
    }
    function runConnect(request, displayName) {
        if (!requireIdle(!backend.nonConnectRunning))
            return;
        status = connectRunning ? "Connection attempt already running…" : "Connecting to " + displayName + "…";
        networkConnectivity = ({ state: "unknown", captive_portal: false, full: false });
        connectingNetworkName = displayName;
        connectWorkspaceId = currentWorkspaceId;
        connectingProgressTick = 0;
        connectingProgressTimer.restart();
        backend.connect(request);
    }
    function resetConnectProgress() { connectingNetworkName = ""; connectingProgressTick = 0; connectingProgressTimer.stop(); }
    function applyConnectResult(result, fallbackText, requestId) {
        const message = result.message || fallbackText || "Wi-Fi connection failed";
        if (result.status === "error") {
            status = message;
            if (Flow.isSecretFailureReason(result.reason)) {
                connectPolicyModel.markSecretStale(connectPolicyModel.lastConnectAp);
                connectPolicyModel.blockLastConnectRetry(Flow.connectFailureRetryMs(result.reason));
                if (connectPolicyModel.lastConnectAp)
                    prompt.openPasswordPrompt(connectPolicyModel.lastConnectAp, Flow.isWrongPasswordReason(result.reason) ? "Wrong password. Enter a new Wi-Fi password." : "Saved password failed. Enter a new Wi-Fi password.");
            }
        } else {
            connectPolicyModel.clearSecretStale(connectPolicyModel.lastConnectAp);
            invalidateShareAvailabilityCache();
            setHeldStatus(message, 2500);
        }
        if (Flow.confirmedPortalResult(result))
            portalModel.launchForConnect(connectPolicyModel.lastConnectAp, result, requestId || "", connectWorkspaceId);
        maybeRunPendingRefresh();
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
    function disconnectNetwork(ap) {
        if (!isActive(ap) || !beginAction())
            return false;
        status = "Disconnecting Wi-Fi…";
        backend.disconnect();
        return true;
    }
    function runProfileActionFor(ap, action) {
        if (!beginAction())
            return false;
        const profile = profileFor(ap);
        if (!profile)
            return false;
        action(profile);
        return true;
    }
    function forgetNetwork(ap) {
        if (!canForgetNetwork(ap)) {
            status = busyMessage;
            return false;
        }
        const profiles = ap.profiles && ap.profiles.length > 0 ? ap.profiles : (profileFor(ap) ? [profileFor(ap)] : []);
        prompt.openForgetPrompt(ap, isActive(ap), profiles);
        return true;
    }
    function executeForget(ap) {
        if (!beginAction())
            return;
        const requestId = "forget-" + Math.round(Date.now());
        status = (isActive(ap) ? "Disconnecting and forgetting " : "Forgetting ") + Presentation.networkName(ap) + "…";
        backend.profile({ operation: "forget", request_id: requestId, key: ap.key });
    }
    function toggleAutoconnectNetwork(ap) { return runProfileActionFor(ap, function (profile) { const enabled = !profile.autoconnect; status = (enabled ? "Enabling" : "Disabling") + " autoconnect for " + profile.id + "…"; backend.profile({ operation: "set-autoconnect", path: profile.path, enabled: enabled }); }); }
    function setMacRandomizedNetwork(ap, enabled) { return runProfileActionFor(ap, function (profile) { status = (enabled ? "Using randomized MAC for " : "Using device MAC for ") + profile.id + "…"; backend.profile({ operation: "set-mac-randomization", path: profile.path, randomized: enabled }); }); }
    function toggleSendHostnameNetwork(ap) { return runProfileActionFor(ap, function (profile) { const enabled = !(profile.privacy && profile.privacy.send_hostname !== false); status = (enabled ? "Sending" : "Hiding") + " device name for " + profile.id + "…"; backend.profile({ operation: "set-send-hostname", path: profile.path, enabled: enabled }); }); }
    function openPortalFor(ap) { portalModel.launchManual(ap, currentWorkspaceId); return true; }
    function triggerDetailAction(id) { return providers.execute(detailResult, id, { workspaceId: currentWorkspaceId }); }
    function executeNetworkAction(actionId, ap) {
        const handlers = {
            connect: function () { return connectNetwork(ap); },
            "cancel-connect": cancelConnection,
            disconnect: function () { return disconnectNetwork(ap); },
            forget: function () { return forgetNetwork(ap); },
            portal: function () { return openPortalFor(ap); },
            share: function () { shareSelected(); return true; },
            autoconnect: function () { return toggleAutoconnectNetwork(ap); },
            "randomized-mac": function () { return setMacRandomizedNetwork(ap, !randomizedMacEnabledFor(ap)); },
            "send-hostname": function () { return toggleSendHostnameNetwork(ap); }
        };
        return handlers[actionId] ? handlers[actionId]() !== false : false;
    }
    function applyNetworks(networks, resetSelection) { results.replaceProviderResults(wifiProviderModel.providerId, wifiProviderModel.resultsForNetworks(networks), resetSelection); }

    function openHiddenNetworkPrompt() { if (beginAnyConnectAction()) prompt.openHiddenNetworkPrompt(); }

    onDetailsOpenChanged: {
        if (detailsOpen)
            Qt.callLater(shareModel.refresh);
        else if (advancedOpen)
            closeAdvancedSettings();
    }
    onDetailApChanged: {
        const profile = profileFor(detailAp);
        if (advancedOpen && (!profile || (profile.path || "") !== advancedProfilePath))
            closeAdvancedSettings();
        if (detailsOpen)
            Qt.callLater(shareModel.refresh);
    }
    onActiveStatusChanged: updateVisibleConnectProgress()
    onActiveScanRequestIdChanged: activeScanRequestId.length > 0 ? scanWatchdogTimer.restart() : scanWatchdogTimer.stop()

    Connections { target: prompt; function onOpenChanged() { if (!prompt.open) Qt.callLater(navigationModel.focusSearch); } }
    Behavior on detailsExpansionProgress {
        enabled: !Theme.noAnimations
        NumberAnimation {
            duration: 220
            easing.type: Easing.InOutSine
        }
    }
    Timer { id: connectingProgressTimer; interval: 120; repeat: true; onTriggered: wifi.connectingProgressTick += 1 }
    Timer { id: scanWatchdogTimer; interval: wifi.scanWatchdogIntervalMs; repeat: false; onTriggered: wifi.handleScanWatchdog() }
    Timer { id: autoRefreshTimer; interval: wifi.autoRefreshIntervalMs; repeat: true; onTriggered: wifi.refresh() }
    Core.ProviderRegistry {
        id: providers

        WifiProvider {
            id: wifiProviderModel
            controller: wifi
        }
    }
    Core.ResultStore { id: results; registry: providers }
    ShareAvailabilityController { id: shareModel; controller: wifi; backend: backend }
    CaptivePortalController { id: portalModel; controller: wifi; backend: backend }
    WifiConnectPolicy { id: connectPolicyModel }
    WifiNavigation { id: navigationModel; controller: wifi }
    WifiBackend { id: backend; controller: wifi }
}
