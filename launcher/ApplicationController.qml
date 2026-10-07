import QtQuick
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation
import "ApplicationLifecycle.js" as Lifecycle

Ui.ProviderChooserController {
    id: controller

    provider: ApplicationProvider {
        id: applicationProvider
        controller: controller
    }
    // Keep the complete catalog local; Shelllist's Rust matcher ranks each edit.
    filterRefreshDelay: 0
    scheduledRefreshDelay: 120
    sharedScreenshotEnabled: true
    sharedScreenshotBlocked: operationBlocked
    sharedScreenshotStartMessage: "Capturing Applications window…"
    onSharedScreenshotStatusChanged: function (message) {
        status = message;
    }

    property string status: "Loading applications…"
    property string catalogError: ""
    readonly property int applicationSearchLimit: 1000
    property string detailsTab: "application"
    viewMemory: Ui.ChooserMemory {
        controller: controller
        key: controller.selectedResult ? controller.selectedResult.key : ""
        tab: controller.detailsTab
        tabs: controller.availableDetailsTabs()
        onContextRestored: Qt.callLater(controller.requestResourceHistory)
        onRestoreRequested: function (open, tab) {
            controller.detailsTab = tab;
            controller.detailsOpen = open;
        }
    }
    property string categoryFilter: ""
    actionInFlight: operations.count > 0
    property alias operations: operationState
    property int actionViewEpoch: 0
    onNavigationInteracted: actionViewEpoch++
    onFilterTextChanged: actionViewEpoch++
    readonly property string selectedActionMessage: selectedResult ? operations.message(selectedResult.id, "") : ""
    signal backgroundActionFailed(string title, string message)
    property bool forceRefresh: false
    property double catalogRevision: -1
    property string revisionRequestId: ""
    property var resourceHistory: []
    property var pendingResourceHistory: []
    property var resourceHistorySummary: null
    property var pendingHistorySummary: null
    property string historyTargetId: ""
    property string activeHistoryRequestId: ""
    property double historyWindowStartMs: 0
    property double historyWindowEndMs: 0
    property string historyRange: "30m"
    property string historyRequestRange: ""
    property string historyCursor: ""
    property string pendingHistoryCursor: ""
    property string activeSettingsRequestId: ""
    // Request-scoped feedback belongs to its application, not the current row.
    property var settingsFeedback: ({})
    readonly property bool historyInFlight: activeHistoryRequestId.length > 0
    readonly property bool settingsInFlight: activeSettingsRequestId.length > 0
    readonly property var selectedApplication: selectedResult ? selectedResult.payload : null
    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) {
        return key.indexOf("query-") === 0;
    })
    readonly property bool screenshotInFlight: sharedScreenshotInFlight
    readonly property bool operationBlocked: screenshotInFlight || settingsInFlight
    readonly property bool resourcesVisible: uiActive && detailsOpen && detailsTab === "resources"
    navigationPrimaryEnabled: hasSelection && !operationBlocked && !operations.busy(selectedResult.id)
    navigationBlocked: operationBlocked

    function clearResourceHistory(): void {
        resourceHistory = [];
        resourceHistorySummary = null;
        pendingHistorySummary = null;
        pendingResourceHistory = [];
        historyTargetId = "";
        activeHistoryRequestId = "";
        historyWindowStartMs = 0;
        historyWindowEndMs = 0;
        historyRequestRange = "";
        historyCursor = "";
        pendingHistoryCursor = "";
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
        // Submitted actions retain their owner/subscription while hidden.
        clearResourceHistory();
        activeSettingsRequestId = "";
    }
    function refresh(explicitRefresh: var): void {
        forceRefresh = explicitRefresh === true;
        catalogError = "";
        status = forceRefresh ? "Refreshing applications…" : "Loading applications…";
        beginProviderQuery({
            workspaceId: currentWorkspaceId
        }, applicationSearchLimit);
    }
    function selectCategory(value: string): void {
        if (categoryFilter === value)
            return;
        categoryFilter = value;
        refresh(false);
    }
    function availableDetailsTabs(): var {
        if (!selectedApplication || selectedApplication.kind === "desktop-shortcut")
            return ["application"];
        return selectedApplication.kind === "desktop-application" ? ["application", "resources", "settings"] : ["application", "resources"];
    }
    function selectDetailsTab(value: string): void {
        if (availableDetailsTabs().includes(value))
            detailsTab = value;
    }
    function cycleDetailsTab(backwards: bool): bool {
        if (!detailsOpen || !hasSelection)
            return false;
        const tabs = availableDetailsTabs();
        detailsTab = tabAfter(tabs, detailsTab, backwards);
        return true;
    }
    function updateApplicationSettings(category: string): bool {
        if (!selectedResult || operationBlocked || operations.busy(selectedResult.id))
            return false;
        settingsFeedback = {targetId: selectedResult.id, category: category, error: ""};
        const requestId = backend.nextRequestId("settings");
        activeSettingsRequestId = requestId;
        status = "Saving application settings…";
        if (!backend.updateSettings(requestId, selectedResult.id, category)) {
            // sendFailed may already have supplied a more specific error.
            if (activeSettingsRequestId === requestId)
                handleFailure(requestId, qsTr("Application service is unavailable."));
            return false;
        }
        return true;
    }
    function applyApplicationSettings(id: string, settings: var): void {
        if (id !== activeSettingsRequestId)
            return;
        activeSettingsRequestId = "";
        settingsFeedback = ({});
        status = "Saved settings for " + (selectedResult ? selectedResult.title : "application");
        scheduleRefresh();
    }
    function refreshMetrics(): void {
        if (!resourcesVisible || operationBlocked || refreshInFlight)
            return;
        forceRefresh = false;
        beginProviderQuery({
            workspaceId: currentWorkspaceId
        }, applicationSearchLimit);
    }
    function requestApplications(id: string, text: string, generation: int, limit: int): void {
        const refreshCatalog = forceRefresh;
        forceRefresh = false;
        backend.query(id, "", categoryFilter, generation, limit, refreshCatalog);
    }
    function resourceHistorySinceMs(): double {
        const durations = {
            "30m": 30 * 60 * 1000,
            "2h": 2 * 60 * 60 * 1000,
            "24h": 24 * 60 * 60 * 1000
        };
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
        if (!targetId || Lifecycle.historyRequestCovered(targetId, historyTargetId, historyInFlight, forceRefresh, historyRange, historyRequestRange))
            return;
        if (targetId !== historyTargetId || historyRange !== historyRequestRange) {
            const previousRequestId = activeHistoryRequestId;
            clearResourceHistory();
            if (previousRequestId)
                backend.cancel(previousRequestId);
        }
        historyTargetId = targetId;
        historyRequestRange = historyRange;
        historyWindowStartMs = resourceHistorySinceMs();
        historyWindowEndMs = Date.now();
        resourceHistory = Lifecycle.mergeResourceHistory(resourceHistory, [], historyWindowStartMs, historyWindowEndMs);
        pendingResourceHistory = [];
        resourceHistorySummary = null;
        pendingHistorySummary = null;
        pendingHistoryCursor = historyCursor;
        activeHistoryRequestId = nextHistoryRequestId();
        backend.history(activeHistoryRequestId, targetId, historyWindowStartMs, historyCursor || null, 1000, historyWindowEndMs);
    }
    function applyResourceHistory(id: string, history: var): void {
        if (id !== activeHistoryRequestId || (history.target_id || "") !== historyTargetId)
            return;
        const summary = history.summary;
        if (!summary || summary.window_start_ms !== historyWindowStartMs || summary.window_end_ms !== historyWindowEndMs) {
            handleFailure(id, "History summary window mismatch; rebuild app-daemon if summaries are missing");
            return;
        }
        if (pendingHistorySummary && pendingHistorySummary.revision !== summary.revision) {
            historyCursor = "";
            resourceHistory = [];
            handleFailure(id, "History changed during pagination; refresh required");
            return;
        }
        pendingHistorySummary = summary;
        if (history.has_more && (!history.next_cursor || history.next_cursor === pendingHistoryCursor)) {
            handleFailure(id, "History pagination did not advance");
            return;
        }
        pendingResourceHistory = pendingResourceHistory.concat(history.points || []);
        pendingHistoryCursor = history.next_cursor || pendingHistoryCursor;
        if (history.has_more) {
            activeHistoryRequestId = nextHistoryRequestId();
            backend.history(activeHistoryRequestId, historyTargetId, historyWindowStartMs, pendingHistoryCursor, 1000, historyWindowEndMs);
            return;
        }
        activeHistoryRequestId = "";
        resourceHistory = Lifecycle.mergeResourceHistory(resourceHistory, pendingResourceHistory, historyWindowStartMs, historyWindowEndMs);
        resourceHistorySummary = pendingHistorySummary;
        pendingHistorySummary = null;
        historyCursor = pendingHistoryCursor;
        pendingResourceHistory = [];
        pendingHistoryCursor = "";
    }
    function cancelQuery(requestId: string): void {
        backend.cancel(requestId);
    }
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
        if (!isActiveQuery(id))
            return;
        catalogRevision = Number(page.revision);
        catalogError = "";
        resultsAboutToChange(true);
        applyProviderQuery(id, applicationProvider.resultsFor(page.applications));
        operations.reconcile(page.applications);
        resultsChanged();
        if (detailsOpen && detailsTab === "resources" && selectedResult && selectedResult.id !== historyTargetId)
            requestResourceHistory();
        status = Presentation.pageStatus(page);
    }
    function executeProviderAction(request: var, params: var): bool {
        if (operationBlocked)
            return false;
        return operations.start(request, params);
    }
    function applyOperation(id: string, operation: var): void {
        operations.apply(id, operation);
    }
    function clearFailedRequest(kind: string, id: string): void {
        if (kind === "settings" && id === activeSettingsRequestId)
            activeSettingsRequestId = "";
    }
    function handleFailure(id: string, message: string): void {
        if (operations.fail(id, message) || operations.finishStatus(id, null, message))
            return;
        if (id.startsWith("action-") || id.startsWith("operation-status-"))
            return; // Obsolete failures cannot overwrite another request.
        if (id === revisionRequestId) {
            revisionRequestId = "";
            refresh(false);
            return;
        }
        const kind = Lifecycle.requestKind(id);
        if (kind === "settings") {
            if (id !== activeSettingsRequestId)
                return;
            clearFailedRequest(kind, id);
            settingsFeedback = Object.assign({}, settingsFeedback, {error: message});
            status = qsTr("Couldn’t save workspace category");
            return;
        }
        if (kind === "history") {
            if (id === activeHistoryRequestId) {
                activeHistoryRequestId = "";
                pendingResourceHistory = [];
                pendingHistoryCursor = "";
                pendingHistorySummary = null;
                resourceHistorySummary = null;
                status = message;
                if (message.indexOf("history changed or expired") >= 0) {
                    historyCursor = "";
                    resourceHistory = [];
                }
            }
            return;
        }
        clearFailedRequest(kind, id);
        if (isActiveQuery(id)) {
            catalogError = message;
            clearProviderResults();
        }
        status = message;
    }
    function handleTransportFailure(message: string): void {
        operations.transportLost(message);
        clearResourceHistory();
        activeSettingsRequestId = "";
        revisionRequestId = "";
        catalogRevision = -1;
        catalogError = message;
        clearProviderResults();
        status = message;
    }
    function canActOnSelection(): bool {
        return !!selectedResult && !operationBlocked && !operations.busy(selectedResult.id);
    }
    function primarySelected(): bool {
        return canActOnSelection() && executeSelected("activate");
    }
    function launchSelected(): bool {
        return canActOnSelection() && selectedApplication.kind === "desktop-application" && executeSelected("launch");
    }
    function triggerDetailAction(actionId: string): bool {
        return canActOnSelection() && executeSelected(actionId);
    }

    onDetailsOpenChanged: if (!detailsOpen)
        clearResourceHistory()
    onResourcesVisibleChanged: if (resourcesVisible)
        Qt.callLater(requestResourceHistory)
    onSelectedResultChanged: {
        if (viewMemory.current && resourcesVisible && availableDetailsTabs().includes(detailsTab))
            requestResourceHistory();
    }

    Timer {
        interval: 2000
        running: controller.uiActive && Object.values(controller.operations.feedback).some(record => record.awaitingWindows && record.windowChecks < 3)
        repeat: true
        onTriggered: if (!controller.refreshInFlight) controller.refresh(false)
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

    ApplicationBackend {
        id: backend
        controller: controller
    }
    ApplicationOperations {
        id: operationState
        controller: controller
        backend: backend
    }
}
