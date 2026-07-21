import QtQuick
import "WifiPresentation.js" as Presentation
import "WifiFlow.js" as Flow
import "NmApiClient.js" as Api
import "NmApi.js" as NmApi
import "."
import Shelllist.Ui

Item {
    id: wifi

    required property WifiPromptController prompt

    property bool uiActive
    property string currentWorkspaceId

    property var activeStatus: null
    property alias filterText: services.queryText
    property alias selectedIndex: services.selectedIndex
    property string status: "Loading Wi-Fi networks…"
    property bool detailsOpen: false
    property real detailsExpansionProgress: detailsOpen ? 1 : 0
    property double statusHoldUntil: 0
    readonly property int closedWindowWidth: Theme.popupClosedWidth
    readonly property int contentMargin: Theme.contentMargin
    readonly property int contentVerticalMargin: Theme.contentVerticalMargin
    readonly property int listPaneWidth: closedWindowWidth - 2 * contentMargin
    readonly property int openWindowWidth: Theme.popupOpenWidth
    readonly property int surfaceWindowWidth: openWindowWidth
    readonly property int detailsGapWidth: Theme.detailsGapWidth
    readonly property real detailsRenderCutoff: 0.025
    readonly property real detailsPaintProgress: (!detailsOpen && detailsExpansionProgress <= detailsRenderCutoff) ? 0 : detailsExpansionProgress
    readonly property real detailsPaneFullWidth: openWindowWidth - closedWindowWidth - detailsGapWidth
    readonly property real detailsPaneWidth: detailsPaintProgress * detailsPaneFullWidth
    readonly property real detailsPaneGapWidth: detailsPaintProgress * detailsGapWidth
    readonly property bool detailsRendered: detailsOpen || detailsExpansionProgress > detailsRenderCutoff
    readonly property int currentWindowWidth: Math.round(closedWindowWidth + detailsPaintProgress * (openWindowWidth - closedWindowWidth))
    readonly property alias backend: services.backend
    readonly property bool actionInFlight: backend.running
    readonly property string detailsTab: advanced.open ? advanced.section : "network"
    readonly property bool scanInFlight: scan.running
    readonly property var filteredResults: services.results.visibleResults
    readonly property var filteredResultsModel: services.results.visibleModel
    readonly property var detailResult: services.results.selected()
    readonly property var detailAp: detailResult ? detailResult.payload : ({})
    readonly property bool hasSelection: filteredResults.length > 0
    readonly property string busyMessage: "Wait for the current Wi-Fi action to finish…"
    readonly property bool shareAvailable: services.share.available
    readonly property string sharePayload: services.share.payload
    readonly property string shareStatus: services.share.status
    readonly property string shareUnavailableMessage: services.share.unavailableMessage
    readonly property alias shareController: services.share
    readonly property alias selectionModel: services.results
    readonly property alias providerModel: services.provider
    readonly property alias providerRegistry: services.providers
    readonly property alias connectPolicy: services.policy
    readonly property alias navigation: services.navigation
    readonly property alias advanced: services.advanced
    readonly property alias connection: services.connection
    readonly property alias actions: services.actions
    readonly property alias scan: services.scan
    readonly property var detailActions: services.providers.actionsFor(detailResult)
    readonly property var daemonEventHandlerByStream: {
        const handlers = ({});
        handlers[NmApi.streams.wifi_status] = function (event) { wifi.applyStatusEvent(event); };
        handlers[NmApi.streams.network_connectivity] = function (event) { connection.applyConnectivityEvent(event); };
        handlers[NmApi.streams.wifi_scan] = function (event) { scan.handleStream(event); };
        handlers[NmApi.streams.wifi_connect] = function (event) { connection.handleEvent(event); };
        handlers[NmApi.streams.wifi_secret] = function (event) { wifi.handleSecretEvent(event); };
        return handlers;
    }

    signal focusSearchRequested
    signal focusListTopRequested
    signal advancedSectionLeaving(string section)
    signal closeWindowRequested

    function activeAccessPoint() { return activeStatus ? (activeStatus.access_point || activeStatus.network || null) : null; }
    function networkName(ap) { return Presentation.networkName(ap); }
    function isActive(ap) { return !!(ap && ap.active); }
    function profileFor(ap) { return Flow.profileForAccessPoint(ap); }
    function selectDetailsTab(tab) {
        if (tab === "network")
            advanced.closeSettings();
        else
            advanced.selectSection(tab);
    }

    function cycleDetailsTab() {
        if (!detailsOpen)
            return;
        const tabs = profileFor(detailAp) ? ["network", "security", "hardware"] : ["network"];
        const index = Math.max(0, tabs.indexOf(detailsTab));
        selectDetailsTab(tabs[(index + 1) % tabs.length]);
    }


    function invalidateShareAvailabilityCache() { services.share.invalidate(); }
    function refreshShareAvailability() { services.share.refresh(); }
    function shareSelected() { services.share.copySelected(); }
    function applyShareResponse(response, errorText) { services.share.applyResponse(response, errorText); }
    function statusIsHeld() { return Date.now() < statusHoldUntil; }
    function setBackgroundStatus(message) { if (!statusIsHeld()) status = message; }
    function setHeldStatus(message, milliseconds) { status = message; statusHoldUntil = Date.now() + milliseconds; }

    function activateUi(workspaceId) {
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
        scan.activate();
        connection.activate();
    }

    function deactivateUi() {
        if (prompt.open)
            cancelPrompt("popover-hidden");
        uiActive = false;
        scan.deactivate();
        connection.deactivate();
    }

    function cancelPrompt(reason) {
        if (!prompt.open)
            return true;
        const mode = prompt.mode;
        const requestId = prompt.secretRequestId;
        let cancelled = true;
        if (mode === "daemon-secret" && requestId.length > 0)
            cancelled = connection.cancelSecret(requestId);
        prompt.cancel();
        console.info("shelllist wifi prompt closed mode=" + mode + " reason=" + (reason || "user")
            + " daemon_cancelled=" + cancelled);
        if (!cancelled)
            status = "Could not cancel the pending Wi-Fi secret request.";
        return cancelled;
    }

    function handleTransportFailure(message, lostRequestIds) {
        const lost = lostRequestIds || [];
        scan.handleTransportFailure();
        connection.handleTransportFailure();
        lost.forEach(function (id) {
            advanced.failCall(id, "nm-daemon transport failed before " + id + " completed: " + message);
        });
        if (lost.indexOf("share") >= 0)
            services.share.fail(message);
        if (prompt.open && prompt.mode === "daemon-secret") {
            console.warn("shelllist wifi daemon secret prompt discarded reason=transport-failure request_id=" + prompt.secretRequestId);
            prompt.cancel();
        }
        status = message + (lost.length > 0 ? " Lost requests: " + lost.join(", ") + "." : "");
    }

    function handleTransportReady() {
        if (uiActive)
            scan.maybeRefresh();
    }

    function refresh() { scan.refresh(); }
    function maybeRunPendingRefresh() { scan.maybeRefresh(); }

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

    function applyStatusEvent(event) {
        if (event.event !== "changed")
            return;
        activeStatus = event.status || null;
    }

    function handleDaemonEvent(event) {
        try {
            Api.requireApiEvent(event);
            const handler = daemonEventHandlerByStream[event.stream];
            if (handler)
                handler(event);
            else
                console.warn("shelllist nm event ignored stream=" + event.stream + " event=" + event.event + " reason=no-handler");
        } catch (error) {
            console.error("shelllist nm event rejected stream=" + (event && event.stream ? event.stream : "unknown") + " error=" + error);
            status = "Could not parse nm-daemon event: " + error;
        }
    }

    function failCall(id, message) {
        if (id === "connect-start")
            connection.resetProgress();
        advanced.failCall(id, message);
        if (id === "share")
            services.share.fail(message);
        status = message;
        maybeRunPendingRefresh();
    }

    function requireIdle(ready) {
        if (!ready)
            status = busyMessage;
        return ready;
    }
    function beginAction() { return requireIdle(!actionInFlight); }
    function primarySelected() { return services.providers.execute(detailResult, "", { workspaceId: currentWorkspaceId }); }
    function triggerDetailAction(id) { return services.providers.execute(detailResult, id, { workspaceId: currentWorkspaceId }); }
    function applyNetworks(networks, resetSelection) { services.results.replaceProviderResults(services.provider.providerId, services.provider.resultsForNetworks(networks), resetSelection); }

    function openHiddenNetworkPrompt() { if (connection.beginAny()) prompt.openHiddenNetworkPrompt(); }

    onDetailsOpenChanged: {
        if (detailsOpen)
            Qt.callLater(services.share.refresh);
        else if (advanced.open)
            advanced.closeSettings();
    }
    onDetailApChanged: {
        advanced.selectionChanged();
        if (detailsOpen)
            Qt.callLater(services.share.refresh);
    }
    onActiveStatusChanged: connection.updateVisibleProgress()

    Connections { target: wifi.prompt; function onOpenChanged() { if (!wifi.prompt.open) Qt.callLater(services.navigation.focusSearch); } }
    Behavior on detailsExpansionProgress {
        enabled: !Theme.noAnimations
        NumberAnimation {
            duration: Theme.animationNormal
            easing.type: Theme.easingGentle
        }
    }
    WifiControllerServices { id: services; controller: wifi; prompt: wifi.prompt }
}
