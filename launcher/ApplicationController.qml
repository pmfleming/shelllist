import QtQuick
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation
import "ApplicationLifecycle.js" as Lifecycle

Ui.ProviderChooserController {
    id: controller

    provider: ApplicationProvider { id: applicationProvider; controller: controller }
    filterRefreshDelay: 90
    scheduledRefreshDelay: 120
    closeDetailsWithoutSelection: true

    property string status: "Loading applications…"
    property string detailsTab: "application"
    actionInFlight: false
    property string activeTargetId: ""
    property string activeOperationId: ""
    property var activeRequest: null
    property bool forceRefresh: false
    property var resourceHistory: []
    property string historyTargetId: ""
    property string activeHistoryRequestId: ""
    readonly property bool historyInFlight: activeHistoryRequestId.length > 0
    readonly property var selectedApplication: selectedResult ? selectedResult.payload : null
    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) { return key.indexOf("query-") === 0; })
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
    navigationPrimaryEnabled: hasSelection && !actionInFlight && !screenshotInFlight
    navigationBlocked: actionInFlight || screenshotInFlight

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
        beginProviderQuery({ workspaceId: currentWorkspaceId }, 500);
    }
    function clearResourceHistory(): void {
        resourceHistory = [];
        historyTargetId = "";
        activeHistoryRequestId = "";
    }
    function activateUi(workspaceId: string): void {
        activateUiState(workspaceId);
        refresh(false);
    }
    function deactivateUi(): void {
        deactivateUiState();
        clearActiveAction();
        clearResourceHistory();
        detailsOpen = false;
    }
    function refresh(explicitRefresh: var): void {
        forceRefresh = explicitRefresh === true;
        status = forceRefresh ? "Refreshing applications…" : "Loading applications…";
        beginProviderQuery({ workspaceId: currentWorkspaceId }, 500);
    }
    function selectDetailsTab(value: string): void {
        if (value === "application"
                || (value === "resources" && selectedApplication
                    && selectedApplication.kind !== "desktop-shortcut"))
            detailsTab = value;
    }
    function cycleDetailsTab(): bool {
        if (!detailsOpen || !hasSelection || selectedApplication.kind === "desktop-shortcut")
            return false;
        detailsTab = detailsTab === "application" ? "resources" : "application";
        return true;
    }
    function refreshMetrics(): void {
        if (!uiActive || actionInFlight || screenshotInFlight || refreshInFlight)
            return;
        forceRefresh = false;
        beginProviderQuery({ workspaceId: currentWorkspaceId }, 500);
    }
    function captureScreenshot(x: real, y: real, width: real, height: real): bool {
        return screenshotCapture.captureRegion(x, y, width, height);
    }
    function requestApplications(id: string, text: string, generation: int, limit: int): void {
        const refreshCatalog = forceRefresh;
        forceRefresh = false;
        backend.query(id, text, generation, limit, refreshCatalog);
    }
    function resourceHistorySinceMs(): double {
        return Date.now() - 30 * 60 * 1000;
    }
    function requestResourceHistory(forceRefresh: var): void {
        if (!uiActive || !detailsOpen || detailsTab !== "resources" || !selectedResult)
            return;
        const targetId = selectedResult.id;
        if (historyInFlight && targetId === historyTargetId)
            return;
        if (forceRefresh !== true && targetId === historyTargetId)
            return;
        historyTargetId = targetId;
        activeHistoryRequestId = "history-" + Date.now();
        backend.history(activeHistoryRequestId, targetId, resourceHistorySinceMs(), null, 120);
    }
    function applyResourceHistory(id: string, history: var): void {
        if (id !== activeHistoryRequestId || (history.target_id || "") !== historyTargetId)
            return;
        activeHistoryRequestId = "";
        resourceHistory = history.points || [];
    }
    function cancelQuery(requestId: string): void { backend.cancelRequest(requestId); }
    function applyApplications(id: string, page: var): void {
        applyProviderQuery(id, applicationProvider.resultsForApplications(page.applications || []));
        if (detailsOpen && detailsTab === "resources"
                && selectedResult && selectedResult.id !== historyTargetId)
            requestResourceHistory();
        status = Presentation.pageStatus(page);
    }
    function executeProviderAction(request: var, params: var): bool {
        if (actionInFlight || screenshotInFlight)
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
        const completed = transition.status === "completed";
        const closing = Presentation.isCloseAction(action);
        if (completed && closing)
            removeClosedInstances(completedRequest, action);
        clearActiveAction();
        status = operation.message || (completed
            ? "Application action completed" : "Application action " + transition.status);
        if (completed && !closing)
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
    function handleFailure(id: string, message: string): void {
        if (id.indexOf("history-") === 0) {
            if (id === activeHistoryRequestId)
                activeHistoryRequestId = "";
            return;
        }
        if (id.indexOf("action-") === 0)
            clearActiveAction();
        if (isActiveQuery(id)) {
            clearProviderResults();
            status = message;
        } else {
            status = message;
        }
    }
    function handleTransportFailure(message: string): void {
        clearActiveAction();
        clearResourceHistory();
        clearProviderResults();
        status = message;
    }
    function primarySelected(): bool {
        if (!selectedResult || actionInFlight || screenshotInFlight)
            return false;
        return executeSelected("activate");
    }
    function launchSelected(): bool {
        if (!selectedResult || actionInFlight || screenshotInFlight
                || selectedApplication.kind !== "desktop-application")
            return false;
        return executeSelected("launch");
    }
    function triggerDetailAction(actionId: string): bool {
        if (!selectedResult || actionInFlight || screenshotInFlight)
            return false;
        return executeSelected(actionId);
    }

    onDetailsOpenChanged: {
        if (detailsOpen)
            detailsTab = "application";
        else
            clearResourceHistory();
    }
    onDetailsTabChanged: if (detailsTab === "resources") requestResourceHistory()
    onSelectedResultChanged: {
        if (selectedApplication && selectedApplication.kind === "desktop-shortcut")
            detailsTab = "application";
        else if (detailsOpen && detailsTab === "resources")
            requestResourceHistory();
    }

    Io.ClipboardScreenshotCapture {
        id: screenshotCapture
        active: controller.uiActive
        blocked: controller.actionInFlight
        startMessage: "Capturing Applications window…"
        onStatusChanged: function (message) { controller.status = message; }
    }

    Timer {
        interval: 20000
        running: controller.actionInFlight
        repeat: false
        onTriggered: controller.recoverTimedOutAction()
    }

    Timer {
        interval: 2000
        running: controller.uiActive
        repeat: true
        onTriggered: controller.refreshMetrics()
    }

    Timer {
        interval: 15000
        running: controller.uiActive && controller.detailsOpen && controller.detailsTab === "resources"
        repeat: true
        onTriggered: controller.requestResourceHistory(true)
    }

    ApplicationBackend { id: backend; controller: controller }
}
