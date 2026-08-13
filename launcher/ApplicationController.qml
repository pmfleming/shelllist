import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserController {
    id: controller

    provider: ApplicationProvider { id: applicationProvider; controller: controller }
    filterRefreshDelay: 90
    scheduledRefreshDelay: 120
    closeDetailsWithoutSelection: true

    property string status: "Loading applications…"
    actionInFlight: false
    property string activeTargetId: ""
    property var activeRequest: null
    property bool forceRefresh: false
    property var resourceHistory: []
    property string historyTargetId: ""
    property string activeHistoryRequestId: ""
    property int historyRequestSequence: 0
    readonly property bool historyInFlight: activeHistoryRequestId.length > 0
    readonly property var selectedApplication: selectedResult ? selectedResult.payload : null
    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) { return key.indexOf("query-") === 0; })
    navigationPrimaryEnabled: hasSelection && !actionInFlight
    navigationBlocked: actionInFlight

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        refresh(false);
    }
    function deactivateUi() {
        deactivateUiState();
        actionInFlight = false;
        activeTargetId = "";
        activeRequest = null;
        resourceHistory = [];
        historyTargetId = "";
        activeHistoryRequestId = "";
        detailsOpen = false;
    }
    function refresh(explicitRefresh) {
        forceRefresh = explicitRefresh === true;
        status = forceRefresh ? "Refreshing applications…" : "Loading applications…";
        beginProviderQuery({ workspaceId: currentWorkspaceId }, 500);
    }
    function refreshMetrics() {
        if (!uiActive || actionInFlight || refreshInFlight)
            return;
        forceRefresh = false;
        beginProviderQuery({ workspaceId: currentWorkspaceId }, 500);
    }
    function requestApplications(id, text, generation, limit) {
        const refreshCatalog = forceRefresh;
        forceRefresh = false;
        backend.query(id, text, generation, limit, refreshCatalog);
    }
    function requestResourceHistory(forceRefresh) {
        if (!uiActive || !detailsOpen || !selectedResult)
            return;
        const targetId = selectedResult.id;
        if (historyInFlight && targetId === historyTargetId)
            return;
        if (forceRefresh !== true && targetId === historyTargetId)
            return;
        historyTargetId = targetId;
        activeHistoryRequestId = "history-" + Date.now() + "-" + (++historyRequestSequence);
        backend.history(activeHistoryRequestId, targetId, 120);
    }
    function applyResourceHistory(id, history) {
        if (id !== activeHistoryRequestId || (history.target_id || "") !== historyTargetId)
            return;
        activeHistoryRequestId = "";
        resourceHistory = history.points || [];
    }
    function cancelQuery(requestId) { backend.cancelRequest(requestId); }
    function applyApplications(id, page) {
        applyProviderQuery(id, applicationProvider.resultsForApplications(page.applications || []));
        if (detailsOpen && selectedResult && selectedResult.id !== historyTargetId)
            requestResourceHistory();
        const count = (page.applications || []).length;
        status = count + (count === 1 ? " application" : " applications");
        if (page.has_more)
            status += " · more available";
        if (!page.hyprland_available)
            status += " · launch only";
    }
    function executeProviderAction(request, params) {
        if (actionInFlight)
            return false;
        actionInFlight = true;
        activeTargetId = request.result.id;
        activeRequest = request;
        status = request.action.label + "…";
        if (!backend.execute(request.id, params)) {
            actionInFlight = false;
            activeTargetId = "";
            activeRequest = null;
            return false;
        }
        return true;
    }
    function applyOperation(id, operation) {
        actionInFlight = false;
        activeTargetId = "";
        status = operation.message || "Application action completed";
        if (activeRequest)
            applicationProvider.executionFinished({ requestId: id, operation: operation });
        const action = activeRequest ? activeRequest.actionId : "";
        activeRequest = null;
        if (action === "close" || action.indexOf("close-window-") === 0) {
            refresh(false);
            return;
        }
        closeWindowRequested();
    }
    function handleFailure(id, message) {
        if (id.indexOf("history-") === 0) {
            if (id === activeHistoryRequestId)
                activeHistoryRequestId = "";
            return;
        }
        if (id.indexOf("action-") === 0) {
            actionInFlight = false;
            activeTargetId = "";
            if (activeRequest)
                applicationProvider.executionFailed({ requestId: id, code: "operation-failed", message: message });
            activeRequest = null;
        }
        if (isActiveQuery(id)) {
            clearProviderResults();
            status = message;
        } else {
            status = message;
        }
    }
    function handleTransportFailure(message) {
        actionInFlight = false;
        activeTargetId = "";
        activeRequest = null;
        activeHistoryRequestId = "";
        resourceHistory = [];
        clearProviderResults();
        status = message;
    }
    function primarySelected() {
        if (!selectedResult || actionInFlight)
            return false;
        return executeSelected("activate");
    }
    function launchSelected() {
        if (!selectedResult || actionInFlight || selectedApplication.kind !== "desktop-application")
            return false;
        return executeSelected("launch");
    }
    function triggerDetailAction(actionId) {
        if (!selectedResult || actionInFlight)
            return false;
        return executeSelected(actionId);
    }

    onDetailsOpenChanged: {
        if (detailsOpen)
            requestResourceHistory();
        else {
            resourceHistory = [];
            historyTargetId = "";
            activeHistoryRequestId = "";
        }
    }
    onSelectedResultChanged: if (detailsOpen) requestResourceHistory()

    Timer {
        interval: 2000
        running: controller.uiActive
        repeat: true
        onTriggered: controller.refreshMetrics()
    }

    Timer {
        interval: 15000
        running: controller.uiActive && controller.detailsOpen
        repeat: true
        onTriggered: controller.requestResourceHistory(true)
    }

    ApplicationBackend { id: backend; controller: controller }
}
