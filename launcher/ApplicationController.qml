import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

Ui.ChooserController {
    id: controller

    property string status: "Loading applications…"
    property bool actionInFlight: false
    property string activeTargetId: ""
    property var activeRequest: null
    property bool forceRefresh: false
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    readonly property var filteredResults: results.visibleResults
    readonly property var filteredResultsModel: results.visibleModel
    readonly property var selectedResult: results.selected()
    readonly property var selectedApplication: selectedResult ? selectedResult.payload : null
    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) { return key.indexOf("query-") === 0; })
    hasSelection: !!selectedResult
    selectionModel: results
    detailActions: selectedResult ? providers.actionsFor(selectedResult) : []
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
        detailsOpen = false;
    }
    function refresh(explicitRefresh) {
        forceRefresh = explicitRefresh === true;
        status = forceRefresh ? "Refreshing applications…" : "Loading applications…";
        results.beginQuery(filterText, { workspaceId: currentWorkspaceId }, [provider.providerId], 500);
    }
    function scheduleRefresh() { refreshTimer.restart(); }
    function requestApplications(id, text, generation, limit) {
        const refreshCatalog = forceRefresh;
        forceRefresh = false;
        backend.query(id, text, generation, limit, refreshCatalog);
    }
    function cancelQuery(requestId) { backend.cancelRequest(requestId); }
    function applyApplications(id, page) {
        results.applyBatch({
            providerId: provider.providerId, queryId: id, replace: true, complete: true,
            results: provider.resultsForApplications(page.applications || [])
        });
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
            provider.executionFinished({ requestId: id, operation: operation });
        activeRequest = null;
        closeWindowRequested();
    }
    function handleFailure(id, message) {
        if (id.indexOf("action-") === 0) {
            actionInFlight = false;
            activeTargetId = "";
            if (activeRequest)
                provider.executionFailed({ requestId: id, code: "operation-failed", message: message });
            activeRequest = null;
        }
        if (id === results.activeQueryId) {
            results.clear();
            status = message;
        } else {
            status = message;
        }
    }
    function handleTransportFailure(message) {
        actionInFlight = false;
        activeTargetId = "";
        activeRequest = null;
        results.clear();
        status = message;
    }
    function primarySelected() {
        if (!selectedResult || actionInFlight)
            return false;
        return providers.execute(selectedResult, "activate", { workspaceId: currentWorkspaceId });
    }
    function launchSelected() {
        if (!selectedResult || actionInFlight || selectedApplication.kind !== "desktop-application")
            return false;
        return providers.execute(selectedResult, "launch", { workspaceId: currentWorkspaceId });
    }
    function triggerDetailAction(actionId) {
        if (!selectedResult || actionInFlight)
            return false;
        return providers.execute(selectedResult, actionId, { workspaceId: currentWorkspaceId });
    }

    Timer { id: searchTimer; interval: 90; repeat: false; onTriggered: if (controller.uiActive) controller.refresh(false) }
    Timer { id: refreshTimer; interval: 120; repeat: false; onTriggered: if (controller.uiActive) controller.refresh(false) }
    onFilterTextChanged: if (uiActive) searchTimer.restart()
    onSelectedResultChanged: if (!hasSelection) detailsOpen = false

    Core.ProviderRegistry {
        id: providers
        ApplicationProvider { id: provider; controller: controller }
    }
    Core.ResultStore { id: results; registry: providers }
    ApplicationBackend { id: backend; controller: controller }
}
