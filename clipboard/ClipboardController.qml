import QtQuick
import Shelllist.Ui as Ui
import "ClipboardFlow.js" as Flow

Ui.ProviderChooserController {
    id: clipboardController

    provider: ClipboardProvider {
        id: clipboardProvider
        controller: clipboardController
    }
    // clip-daemon ranks its catalog; QML keeps only requested visible pages.
    providerRankedResults: true
    filterRefreshDelay: 75
    scheduledRefreshDelay: 90

    property string status: "Loading clipboard history…"
    property string sessionId: ""
    actionInFlight: false
    property bool screenshotInFlight: false
    property string activeAction: ""
    property string activeOperationId: ""
    property var handledTerminalOperations: ({})
    property var settings: ({
            max_entries: 750,
            max_favorites: 100,
            max_entry_bytes: 16777216,
            capture_paused: false,
            private_mode: false
        })
    property var wipeChallenge: null
    property bool deleteMenuOpen: false
    property bool deleteConfirmationOpen: false
    property bool bulkDeleteConfirmationOpen: false
    property bool multiSelectMode: false
    property var multiSelectedIds: ({})
    property bool selectCurrentAfterRefresh: false
    property int activeAnnotationSelectionIndex: -1
    property int selectionIndexAfterRefresh: -1
    property string activeHistoryQueryId: ""
    property string revisionRequestId: ""
    property string historyRevision: ""
    property int activeHistoryGeneration: 0
    property string historyCursor: ""
    property string historyQueryId: ""
    property string historyQueryText: ""
    property bool appendingHistory: false
    property int historyPageNumber: 0
    readonly property int historyPageSize: 200
    readonly property alias detailState: detailsModel
    readonly property var selectedEntry: selectedResult ? selectedResult.payload : null
    readonly property var multiSelectedEntries: Object.keys(multiSelectedIds).map(function (entryId) {
        return multiSelectedIds[entryId];
    })
    readonly property int multiSelectedCount: multiSelectedEntries.length
    readonly property bool allVisibleSelected: filteredResults.length > 0 && filteredResults.every(function (result) {
        return !!result.payload && !!multiSelectedIds[result.payload.id];
    })
    navigationPrimaryEnabled: hasSelection && !multiSelectMode && !actionInFlight && !wipeChallenge && !detailState.editorFocused
    navigationCloseEnabled: false

    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) {
        return key.indexOf("query-") === 0;
    })
    readonly property bool backgroundOperationInFlight: activeAction === "annotate" && activeOperationId.length > 0
    signal hideRequested

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        backend.beginSession();
        backend.getSettings();
        if (!historyRevision.length) {
            selectCurrentAfterRefresh = true;
            selectFirst();
            refresh();
            return;
        }
        revisionRequestId = "revision-" + Date.now();
        if (!backend.revision(revisionRequestId)) {
            revisionRequestId = "";
            selectCurrentAfterRefresh = true;
            refresh();
        }
    }
    function finishEditSession(): void {
        if (!detailState.editing)
            return;
        if (detailState.editIsDirect && detailState.editDirty)
            detailState.commitEdit();
        else
            detailState.cancelEdit();
    }
    function deactivateUi() {
        if (sessionId.length > 0)
            backend.endSession(sessionId);
        finishEditSession();
        const keepBackgroundOperation = backgroundOperationInFlight;
        deactivateUiState();
        sessionId = "";
        if (!keepBackgroundOperation) {
            actionInFlight = false;
            activeAction = "";
            activeOperationId = "";
            handledTerminalOperations = ({});
        }
        screenshotInFlight = false;
        activeHistoryQueryId = "";
        revisionRequestId = "";
        historyCursor = "";
        deleteMenuOpen = false;
        deleteConfirmationOpen = false;
        bulkDeleteConfirmationOpen = false;
        leaveMultiSelect();
        detailsOpen = false;
        detailState.clear();
    }
    function dismissEditor(): bool {
        if (!detailState.editing)
            return false;
        if (detailState.editIsDirect)
            detailState.finishDirectEdit();
        else
            detailState.cancelEdit();
        return true;
    }
    function dismissClipboardOperation(): bool {
        if (activeOperationId.length > 0)
            cancelActiveOperation();
        else if (bulkDeleteConfirmationOpen)
            cancelBulkDelete();
        else if (deleteConfirmationOpen)
            cancelDelete();
        else if (wipeChallenge)
            cancelWipe();
        else
            return false;
        return true;
    }
    function dismissNavigation(): bool {
        if (dismissNavigationHelp() || dismissEditor() || dismissClipboardOperation())
            return true;
        if (deleteMenuOpen) {
            closeDeleteMenu();
            return true;
        }
        if (multiSelectMode) {
            leaveMultiSelect();
            return true;
        }
        return dismissDetailsOrWindow();
    }
    function refresh() {
        status = "Loading clipboard history…";
        beginProviderQuery({}, 100);
    }
    function requestHistory(id, text, generation, limit) {
        activeHistoryQueryId = id;
        historyQueryId = id;
        historyQueryText = text;
        activeHistoryGeneration = generation;
        historyCursor = "";
        appendingHistory = false;
        backend.query(id, text, generation, historyPageSize, "");
    }
    function maybeLoadMoreHistory() {
        if (filteredResults.length > 0 && selectedIndex >= filteredResults.length - 4)
            loadMoreHistory();
    }
    function loadMoreHistory() {
        if (!historyCursor.length || activeHistoryQueryId.length || historyQueryText !== filterText)
            return;
        appendingHistory = true;
        activeHistoryQueryId = historyQueryId + "-page-" + (++historyPageNumber);
        backend.query(activeHistoryQueryId, historyQueryText, activeHistoryGeneration, historyPageSize, historyCursor);
    }
    function cancelQuery(requestId) {
        if (requestId === historyQueryId) {
            if (activeHistoryQueryId.length)
                backend.cancelRequest(activeHistoryQueryId);
            activeHistoryQueryId = "";
            historyCursor = "";
        }
    }
    function selectCurrentEntry(currentEntry: var): void {
        if (!selectCurrentAfterRefresh)
            return;
        if (selectionIndexAfterRefresh >= 0) {
            const retainedIndex = filteredResults.length > 0 ? Math.min(selectionIndexAfterRefresh, filteredResults.length - 1) : 0;
            selectionIndexAfterRefresh = -1;
            selectCurrentAfterRefresh = false;
            select(retainedIndex);
            return;
        }
        const currentId = currentEntry ? currentEntry.id : "";
        const currentIndex = filteredResults.findIndex(function (result) {
            return result.id === currentId;
        });
        select(currentIndex >= 0 ? currentIndex : 0);
        selectCurrentAfterRefresh = false;
    }
    function applyRevision(id: string, revision: var): void {
        if (id !== revisionRequestId)
            return;
        revisionRequestId = "";
        if (revision !== historyRevision) {
            selectCurrentAfterRefresh = true;
            refresh();
            return;
        }
        status = filteredResults.length + " clipboard entries";
    }
    function applyHistory(id, history) {
        if (id !== activeHistoryQueryId)
            return;
        if (typeof history.snapshot_revision !== "string")
            return handleFailure(id, "Rebuild clip-daemon for revision-bound history search");
        historyRevision = history.snapshot_revision;
        historyCursor = history.next_cursor || "";
        const entries = history.entries || [];
        const results = clipboardProvider.resultsForEntries(entries, history.offset || 0);
        activeHistoryQueryId = "";
        if (appendingHistory)
            selectionModel.applyNormalizedBatch({ providerId: "clipboard", queryId: historyQueryId, replace: false, results: results });
        else
            applyProviderQuery(historyQueryId, results);
        reconcileMultiSelection(filteredResults.map(function (result) { return result.payload; }));
        selectCurrentEntry(history.current || null);
        status = filteredResults.length + " of " + history.total + " clipboard entries" + (history.search_limited ? " · search limited to recent entries" : "");
        detailState.scheduleLoad();
    }
    function applySession(session) {
        sessionId = ["hidden", "ended"].includes(session.state) ? "" : (session.id || "");
        if (session.state === "hidden")
            hideRequested();
    }
    function handleHistoryChanged(revision: var): void {
        if (revisionRequestId.length > 0)
            return;
        scheduleRefresh();
    }
    function actionEntry() {
        return Flow.detailedEntry(selectedEntry, detailState.value, detailState.replacedSourceIds);
    }
    function runAction(actionName, fileIndex, entry) {
        const target = entry || actionEntry();
        if (!target || actionInFlight)
            return false;
        actionInFlight = true;
        activeAction = actionName;
        backend.action("action-" + actionName, target, actionName, sessionId, fileIndex);
        return true;
    }
    function captureScreenshot(x, y, width, height) {
        if (screenshotInFlight || actionInFlight)
            return false;
        screenshotInFlight = true;
        actionInFlight = true;
        activeAction = "screenshot";
        status = "Capturing clipboard window…";
        backend.captureScreenshot(x, y, width, height);
        return true;
    }
    function copySelected() {
        runAction("copy");
    }
    function pasteSelected() {
        if (!detailState.preparePaste())
            runAction("paste");
    }
    function primarySelected() {
        if (!selectedEntry || actionInFlight || wipeChallenge)
            return false;
        if (selectedEntry.kind === "binary")
            copySelected();
        else
            pasteSelected();
        return true;
    }
    function pasteImageAsFile() {
        runAction("image-as-file");
    }
    function openDeleteMenu() {
        if (!actionInFlight && !wipeChallenge)
            deleteMenuOpen = true;
    }
    function closeDeleteMenu() {
        deleteMenuOpen = false;
    }
    function reconcileMultiSelection(entries: var): void {
        if (!multiSelectMode)
            return;
        const next = ({});
        (entries || []).forEach(function (entry) {
            if (multiSelectedIds[entry.id])
                next[entry.id] = entry;
        });
        multiSelectedIds = next;
    }
    function enterMultiSelect() {
        closeDeleteMenu();
        closeDetails();
        multiSelectMode = true;
        multiSelectedIds = ({});
        if (selectedEntry)
            setEntrySelected(selectedEntry, true);
    }
    function leaveMultiSelect() {
        multiSelectMode = false;
        multiSelectedIds = ({});
    }
    function setEntrySelected(entry: var, selected: bool): void {
        if (!entry || !entry.id)
            return;
        const next = Object.assign({}, multiSelectedIds);
        if (selected)
            next[entry.id] = entry;
        else
            delete next[entry.id];
        multiSelectedIds = next;
    }
    function toggleEntrySelection(rowIndex: int): void {
        const result = filteredResults[rowIndex];
        if (!result || !result.payload)
            return;
        select(rowIndex);
        const entryId = result.payload.id;
        setEntrySelected(result.payload, !multiSelectedIds[entryId]);
    }
    function selectAllVisible() {
        const next = Object.assign({}, multiSelectedIds);
        filteredResults.forEach(function (result) {
            if (result.payload)
                next[result.payload.id] = result.payload;
        });
        multiSelectedIds = next;
    }
    function requestDeleteCurrent() {
        closeDeleteMenu();
        requestDelete();
    }
    function requestDeleteAll() {
        closeDeleteMenu();
        requestWipe();
    }
    function requestBulkDelete() {
        if (multiSelectedCount > 0 && !actionInFlight)
            bulkDeleteConfirmationOpen = true;
    }
    function cancelBulkDelete() {
        bulkDeleteConfirmationOpen = false;
    }
    function confirmBulkDelete() {
        if (multiSelectedCount <= 0 || actionInFlight)
            return;
        const entries = multiSelectedEntries.map(function (entry) {
            return {
                entry_id: entry.id,
                revision: entry.revision
            };
        });
        bulkDeleteConfirmationOpen = false;
        actionInFlight = true;
        activeAction = "delete-many";
        backend.deleteEntries("delete-many-" + Date.now(), entries);
    }
    function annotateImage() {
        const originalIndex = selectedIndex;
        if (runAction("annotate"))
            activeAnnotationSelectionIndex = originalIndex;
    }
    function openUrl() {
        runAction("open-url");
    }
    function requestDelete() {
        if (selectedEntry)
            deleteConfirmationOpen = true;
    }
    function cancelDelete() {
        deleteConfirmationOpen = false;
    }
    function confirmDelete() {
        deleteConfirmationOpen = false;
        runAction("delete");
    }
    function cancelActiveOperation() {
        if (activeOperationId.length > 0)
            backend.cancelOperation(activeOperationId);
        actionInFlight = false;
        activeAction = "";
        activeOperationId = "";
        status = "Clipboard operation cancelled";
    }
    function applySettings(value) {
        settings = value;
        status = value.private_mode ? "Private mode · capture paused" : (value.capture_paused ? "Clipboard capture paused" : status);
    }
    function applyCapture(value) {
        status = value.private_mode ? "Private mode enabled" : (value.paused ? "Clipboard capture paused" : "Clipboard capture resumed");
    }
    function finishWipe() {
        wipeChallenge = null;
        closeDetails();
        scheduleRefresh();
    }
    function finishDelete() {
        closeDetails();
        scheduleRefresh();
    }
    function finishBulkDelete() {
        cancelBulkDelete();
        leaveMultiSelect();
        closeDetails();
        scheduleRefresh();
    }
    function finishScreenshot() {
        screenshotInFlight = false;
        selectCurrentAfterRefresh = true;
        scheduleRefresh();
    }
    function finishAnnotate() {
        // Annotation changes the entry's content-derived ID, so stable-key
        // retention cannot find it. The daemon preserves its history position;
        // restore that position instead of selecting an unrelated current item.
        selectionIndexAfterRefresh = activeAnnotationSelectionIndex;
        activeAnnotationSelectionIndex = -1;
        selectCurrentAfterRefresh = true;
        scheduleRefresh();
    }
    function finishPaste(operation) {
        if (operation.status === "paste-prepared")
            backend.hideSession(sessionId);
        else if (operation.action === "image-as-file")
            scheduleRefresh();
    }
    function terminalOperationHandled(operation: var): bool {
        const result = Flow.rememberTerminal(operation, handledTerminalOperations, 64);
        handledTerminalOperations = result.handled;
        return result.duplicate;
    }
    function updateOperationState(operation: var): void {
        actionInFlight = Flow.operationRunning(operation);
        activeAction = actionInFlight ? operation.action : "";
        activeOperationId = actionInFlight ? (operation.id || "") : "";
        status = operation.message || "Clipboard operation completed";
    }
    function completeOperation(operation: var): void {
        const completions = ({
                paste: finishPaste,
                "image-as-file": finishPaste,
                wipe: finishWipe,
                "delete": finishDelete,
                "delete-many": finishBulkDelete,
                screenshot: finishScreenshot,
                annotate: finishAnnotate,
                copy: scheduleRefresh,
                favorite: scheduleRefresh,
                unfavorite: scheduleRefresh
            });
        const completion = completions[operation.action];
        if (completion)
            completion(operation);
    }
    function applyOperation(operation: var): void {
        if (!operation || terminalOperationHandled(operation))
            return;
        updateOperationState(operation);
        if (operation.action === "annotate" && actionInFlight) {
            hideRequested();
            return;
        }
        if (!actionInFlight)
            completeOperation(operation);
    }
    function requestWipe() {
        if (!actionInFlight)
            backend.prepareWipe();
    }
    function applyWipeChallenge(challenge) {
        wipeChallenge = challenge;
    }
    function cancelWipe() {
        wipeChallenge = null;
    }
    function confirmWipe() {
        if (!wipeChallenge)
            return;
        actionInFlight = true;
        backend.commitWipe(wipeChallenge.id);
    }
    function openDetails() {
        if (!hasSelection || multiSelectMode)
            return;
        detailsOpen = true;
        detailState.load();
    }
    function closeDetails() {
        detailsOpen = false;
    }
    function toggleDetails() {
        detailsOpen ? closeDetails() : openDetails();
    }
    function isActionRequest(id) {
        return id.indexOf("action-") === 0 || id.indexOf("wipe-") === 0 || id.indexOf("delete-many-") === 0 || id.indexOf("edit-") === 0 || id === "capture-screenshot";
    }
    function handleFailure(id, message) {
        if (id === revisionRequestId) {
            revisionRequestId = "";
            selectCurrentAfterRefresh = true;
            refresh();
            return;
        }
        if (isActionRequest(id)) {
            actionInFlight = false;
            activeAction = "";
            activeOperationId = "";
            if (id === "action-annotate")
                activeAnnotationSelectionIndex = -1;
            if (id === "capture-screenshot")
                screenshotInFlight = false;
        }
        if (id === activeHistoryQueryId || isActiveQuery(id)) {
            activeHistoryQueryId = "";
            historyCursor = "";
            status = message;
            if (message.indexOf("stale-cursor") >= 0)
                scheduleRefresh();
        } else if (!detailState.handleFailure(id, message)) {
            status = message;
        }
    }
    function handleEventGap(stream: string): void {
        if (stream === "clipboard.operation") {
            actionInFlight = false;
            activeAction = "";
            activeOperationId = "";
        }
        status = "Clipboard events were missed; refreshing current state…";
        scheduleRefresh();
    }
    function handleTransportReady() {
        if (!uiActive)
            return;
        // Activation may already have queued these requests. Recovery reloads
        // state, never replays mutations or automatically retries a draft.
        if (!backend.isPending("session-begin"))
            backend.beginSession();
        if (!backend.isPending("settings-get"))
            backend.getSettings();
        if (!refreshInFlight) {
            selectCurrentAfterRefresh = true;
            refresh();
        }
    }
    function handleTransportFailure(message) {
        detailState.preserveDraftOnDisconnect(message);
        detailState.clear();
        clearProviderResults();
        sessionId = "";
        actionInFlight = false;
        screenshotInFlight = false;
        activeAction = "";
        activeOperationId = "";
        activeAnnotationSelectionIndex = -1;
        selectionIndexAfterRefresh = -1;
        deleteMenuOpen = false;
        deleteConfirmationOpen = false;
        bulkDeleteConfirmationOpen = false;
        leaveMultiSelect();
        activeHistoryQueryId = "";
        revisionRequestId = "";
        historyRevision = "";
        historyCursor = "";
        status = message;
    }
    onSelectedResultChanged: {
        deleteConfirmationOpen = false;
        detailState.selectionChanged();
        Qt.callLater(maybeLoadMoreHistory);
    }
    ClipboardBackend {
        id: backend
        controller: clipboardController
    }
    ClipboardDetailsController {
        id: detailsModel
        controller: clipboardController
        daemonBackend: backend
    }
}
