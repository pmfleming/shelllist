import QtQuick
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation
import "ApplicationLifecycle.js" as Lifecycle

Ui.ProviderChooserController {
    id: controller

    provider: ApplicationProvider { id: applicationProvider; controller: controller }
    // Keep the complete catalog local; Shelllist's Rust matcher ranks each edit.
    filterRefreshDelay: 0
    scheduledRefreshDelay: 120
    closeDetailsWithoutSelection: true
    sharedScreenshotEnabled: true
    sharedScreenshotBlocked: operationBlocked
    sharedScreenshotStartMessage: "Capturing Applications window…"
    onSharedScreenshotStatusChanged: function (message) { status = message; }

    property string status: "Loading applications…"
    readonly property int applicationSearchLimit: 1000
    property string detailsTab: "application"
    property string categoryFilter: ""
    actionInFlight: false
    property string activeTargetId: ""
    property string activeOperationId: ""
    property var activeRequest: null
    property bool forceRefresh: false
    property double catalogRevision: -1
    property string revisionRequestId: ""
    property var resourceHistory: []
    property var pendingResourceHistory: []
    property string historyTargetId: ""
    property string activeHistoryRequestId: ""
    property double historyWindowStartMs: 0
    property double historyWindowEndMs: 0
    property string historyRange: "30m"
    property string activeSettingsRequestId: ""
    readonly property bool historyInFlight: activeHistoryRequestId.length > 0
    readonly property bool settingsInFlight: activeSettingsRequestId.length > 0
    readonly property var selectedApplication: selectedResult ? selectedResult.payload : null
    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) { return key.indexOf("query-") === 0; })
    readonly property bool screenshotInFlight: sharedScreenshotInFlight
    readonly property bool operationBlocked: actionInFlight || screenshotInFlight || settingsInFlight
    readonly property bool resourcesVisible: uiActive && detailsOpen && detailsTab === "resources"
    navigationPrimaryEnabled: hasSelection && !operationBlocked
    navigationBlocked: operationBlocked

    function clearActiveAction(): void {
        actionInFlight = false;
        activeTargetId = "";
        activeOperationId = "";
        activeRequest = null;
    }
    function recoverTimedOutAction(): void {
        if (!actionInFlight)
            return;
        clearActiveAction();
        status = "Application launch status timed out; refreshed current state";
        forceRefresh = false;
        beginProviderQuery({ workspaceId: currentWorkspaceId }, applicationSearchLimit);
    }
    function clearResourceHistory(): void {
        resourceHistory = [];
        pendingResourceHistory = [];
        historyTargetId = "";
        activeHistoryRequestId = "";
        historyWindowStartMs = 0;
        historyWindowEndMs = 0;
    }
    function activateUi(workspaceId: string): void {
        activateUiState(workspaceId);
        if (catalogRevision < 0) {
            refresh(false);
            return;
        }
        revisionRequestId = "revision-" + Date.now();
        if (!backend.revision(revisionRequestId)) {
            revisionRequestId = "";
            refresh(false);
        }
    }
    function deactivateUi(): void {
        deactivateUiState();
        clearActiveAction();
        clearResourceHistory();
        activeSettingsRequestId = "";
        detailsOpen = false;
    }
    function refresh(explicitRefresh: var): void {
        forceRefresh = explicitRefresh === true;
        status = forceRefresh ? "Refreshing applications…" : "Loading applications…";
        beginProviderQuery({ workspaceId: currentWorkspaceId }, applicationSearchLimit);
    }
    function selectCategory(value: string): void {
        if (categoryFilter === value)
            return;
        categoryFilter = value;
        detailsOpen = false;
        refresh(false);
    }
    function availableDetailsTabs(): var {
        if (!selectedApplication || selectedApplication.kind === "desktop-shortcut")
            return ["application"];
        return selectedApplication.kind === "desktop-application"
            ? ["application", "resources", "settings"] : ["application", "resources"];
    }
    function selectDetailsTab(value: string): void {
        if (availableDetailsTabs().includes(value))
            detailsTab = value;
    }
    function cycleDetailsTab(): bool {
        if (!detailsOpen || !hasSelection)
            return false;
        const tabs = availableDetailsTabs();
        detailsTab = tabs[(tabs.indexOf(detailsTab) + 1) % tabs.length];
        return true;
    }
    function updateApplicationSettings(category: string): bool {
        if (!selectedResult || operationBlocked)
            return false;
        activeSettingsRequestId = "settings-" + Date.now();
        status = "Saving application settings…";
        if (!backend.updateSettings(activeSettingsRequestId, selectedResult.id, category)) {
            activeSettingsRequestId = "";
            return false;
        }
        return true;
    }
    function applyApplicationSettings(id: string, settings: var): void {
        if (id !== activeSettingsRequestId)
            return;
        activeSettingsRequestId = "";
        status = "Saved settings for " + (selectedResult ? selectedResult.title : "application");
        scheduleRefresh();
    }
    function refreshMetrics(): void {
        if (!resourcesVisible || operationBlocked || refreshInFlight)
            return;
        forceRefresh = false;
        beginProviderQuery({ workspaceId: currentWorkspaceId }, applicationSearchLimit);
    }
    function requestApplications(id: string, text: string, generation: int, limit: int): void {
        const refreshCatalog = forceRefresh;
        forceRefresh = false;
        backend.query(id, "", categoryFilter, generation, limit, refreshCatalog);
    }
    function resourceHistorySinceMs(): double {
        const durations = { "30m": 30 * 60 * 1000, "2h": 2 * 60 * 60 * 1000,
            "24h": 24 * 60 * 60 * 1000 };
        return Date.now() - (durations[historyRange] || durations["30m"]);
    }
    function selectHistoryRange(value: string): void {
        if (!["30m", "2h", "24h"].includes(value) || historyRange === value)
            return;
        historyRange = value;
        requestResourceHistory(true);
    }
    function nextHistoryRequestId(): string {
        return backend.nextRequestId("history");
    }
    function requestResourceHistory(forceRefresh: var): void {
        const targetId = resourcesVisible && selectedResult ? selectedResult.id : "";
        if (!targetId || Lifecycle.historyRequestCovered(
                targetId, historyTargetId, historyInFlight, forceRefresh))
            return;
        historyTargetId = targetId;
        historyWindowStartMs = resourceHistorySinceMs();
        historyWindowEndMs = Date.now();
        pendingResourceHistory = [];
        activeHistoryRequestId = nextHistoryRequestId();
        backend.history(activeHistoryRequestId, targetId, historyWindowStartMs, null, 1000);
    }
    function applyResourceHistory(id: string, history: var): void {
        if (id !== activeHistoryRequestId || (history.target_id || "") !== historyTargetId)
            return;
        pendingResourceHistory = pendingResourceHistory.concat(history.points || []);
        if (history.has_more && history.next_cursor) {
            activeHistoryRequestId = nextHistoryRequestId();
            backend.history(activeHistoryRequestId, historyTargetId,
                historyWindowStartMs, history.next_cursor, 1000);
            return;
        }
        activeHistoryRequestId = "";
        historyWindowEndMs = Date.now();
        resourceHistory = pendingResourceHistory;
        pendingResourceHistory = [];
    }
    function cancelQuery(requestId: string): void { backend.cancelRequest(requestId); }
    function applyRevision(id: string, revision: var): void {
        if (id !== revisionRequestId)
            return;
        revisionRequestId = "";
        if (Number(revision) !== catalogRevision) {
            refresh(false);
            return;
        }
        status = filteredResults.length + " applications";
    }
    function applyApplications(id: string, page: var): void {
        catalogRevision = Number(page.revision);
        applyProviderQuery(id, applicationProvider.resultsForApplications(page.applications || []));
        if (detailsOpen && detailsTab === "resources"
                && selectedResult && selectedResult.id !== historyTargetId)
            requestResourceHistory();
        status = Presentation.pageStatus(page);
    }
    function executeProviderAction(request: var, params: var): bool {
        if (operationBlocked)
            return false;
        actionInFlight = true;
        activeTargetId = request.result.id;
        activeRequest = request;
        status = request.action.label + "…";
        if (!backend.execute(request.id, params)) {
            clearActiveAction();
            return false;
        }
        return true;
    }
    function applyActiveOperation(transition: var, operation: var): void {
        activeOperationId = transition.operationId;
        status = operation.message || (transition.accepted
            ? "Application action accepted…" : activeRequest.action.label + "…");
    }
    function applyCompletedOperation(transition: var, operation: var): void {
        const completedRequest = activeRequest;
        const action = completedRequest.actionId;
        const disposition = Lifecycle.completionDisposition(
            transition.status, Presentation.isCloseAction(action));
        if (disposition.removeInstances)
            removeClosedInstances(completedRequest, action);
        clearActiveAction();
        status = operation.message || (disposition.completed
            ? "Application action completed" : "Application action " + transition.status);
        if (disposition.closeSurface)
            closeWindowRequested();
    }
    function applyOperation(id: string, operation: var): void {
        const transition = Lifecycle.operationTransition(activeRequest, activeTargetId,
            activeOperationId, id, operation);
        if (!transition)
            return;
        if (transition.stage === "active")
            applyActiveOperation(transition, operation);
        else
            applyCompletedOperation(transition, operation);
    }
    function removeClosedInstances(request: var, action: string): void {
        const targetId = request.result.id;
        const windowId = (request.action.metadata || ({})).windowId || "";
        const next = filteredResults.map(function (result) {
            if (result.id !== targetId)
                return result;
            return applicationProvider.resultForApplication(
                Presentation.withoutClosedInstances(result.payload, action, windowId));
        });
        replaceProviderResults(next, false);
    }
    function clearFailedRequest(kind: string, id: string): void {
        if (kind === "settings" && id === activeSettingsRequestId)
            activeSettingsRequestId = "";
        else if (kind === "action")
            clearActiveAction();
    }
    function handleFailure(id: string, message: string): void {
        if (id === revisionRequestId) {
            revisionRequestId = "";
            refresh(false);
            return;
        }
        const kind = Lifecycle.requestKind(id);
        if (kind === "history") {
            if (id === activeHistoryRequestId) {
                activeHistoryRequestId = "";
                pendingResourceHistory = [];
            }
            return;
        }
        clearFailedRequest(kind, id);
        if (isActiveQuery(id))
            clearProviderResults();
        status = message;
    }
    function handleTransportFailure(message: string): void {
        clearActiveAction();
        clearResourceHistory();
        activeSettingsRequestId = "";
        revisionRequestId = "";
        catalogRevision = -1;
        clearProviderResults();
        status = message;
    }
    function canActOnSelection(): bool { return !!selectedResult && !operationBlocked; }
    function primarySelected(): bool {
        return canActOnSelection() && executeSelected("activate");
    }
    function launchSelected(): bool {
        return canActOnSelection() && selectedApplication.kind === "desktop-application"
            && executeSelected("launch");
    }
    function triggerDetailAction(actionId: string): bool {
        return canActOnSelection() && executeSelected(actionId);
    }

    onDetailsOpenChanged: {
        if (detailsOpen)
            detailsTab = "application";
        else
            clearResourceHistory();
    }
    onDetailsTabChanged: if (detailsTab === "resources") requestResourceHistory()
    onSelectedResultChanged: {
        if (!availableDetailsTabs().includes(detailsTab))
            detailsTab = "application";
        else if (resourcesVisible)
            requestResourceHistory();
    }

    Timer {
        interval: 20000
        running: controller.actionInFlight
        repeat: false
        onTriggered: controller.recoverTimedOutAction()
    }

    Timer {
        interval: 2000
        running: controller.resourcesVisible
        repeat: true
        onTriggered: controller.refreshMetrics()
    }

    Timer {
        interval: 15000
        running: controller.resourcesVisible
        repeat: true
        onTriggered: controller.requestResourceHistory(true)
    }

    ApplicationBackend { id: backend; controller: controller }
}
