import QtQuick
import Shelllist.Ui as Ui
import "ClipboardFlow.js" as Flow

Ui.ProviderChooserController {
    id: clipboardController

    provider: ClipboardProvider { id: clipboardProvider; controller: clipboardController }
    // Load history pages once and let the shared Rust matcher rank each edit.
    filterRefreshDelay: 0
    scheduledRefreshDelay: 90

    property string status: "Loading clipboard history…"
    property string sessionId: ""
    actionInFlight: false
    property bool screenshotInFlight: false
    property string activeAction: ""
    property string activeOperationId: ""
    property var handledTerminalOperations: ({})
    property var settings: ({ max_entries: 750, max_favorites: 100, max_entry_bytes: 16777216, capture_paused: false, private_mode: false })
    property var wipeChallenge: null
    property bool deleteConfirmationOpen
    property bool selectCurrentAfterRefresh: false
    property string activeHistoryQueryId: ""
    property string revisionRequestId: ""
    property double historyRevision: -1
    property int activeHistoryGeneration: 0
    property var pendingHistoryEntries: []
    readonly property int historyPageSize: 200
    readonly property int historySearchLimit: Math.min(5000,
        Math.max(historyPageSize, Number(settings.max_entries) || 750))
    readonly property alias detailState: detailsModel
    readonly property var selectedEntry: selectedResult ? selectedResult.payload : null
    navigationPrimaryEnabled: hasSelection
        && !actionInFlight && !wipeChallenge && !detailState.editorFocused
    navigationCloseEnabled: false

    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) { return key.indexOf("query-") === 0; })
    signal hideRequested

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        backend.beginSession();
        backend.getSettings();
        if (historyRevision < 0) {
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
        deactivateUiState();
        sessionId = "";
        actionInFlight = false;
        screenshotInFlight = false;
        activeAction = "";
        activeOperationId = "";
        handledTerminalOperations = ({});
        activeHistoryQueryId = "";
        revisionRequestId = "";
        pendingHistoryEntries = [];
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
        return dismissDetailsOrWindow();
    }
    function refresh() {
        status = "Loading clipboard history…";
        beginProviderQuery({}, 100);
    }
    function requestHistory(id, text, generation, limit) {
        activeHistoryQueryId = id;
        activeHistoryGeneration = generation;
        pendingHistoryEntries = [];
        backend.query(id, "", generation, historyPageSize, 0);
    }
    function cancelQuery(requestId) {
        if (requestId === activeHistoryQueryId) {
            activeHistoryQueryId = "";
            pendingHistoryEntries = [];
        }
        backend.cancelRequest(requestId);
    }
    function selectCurrentEntry(currentEntry: var): void {
        if (!selectCurrentAfterRefresh)
            return;
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
        if (Number(revision) !== historyRevision) {
            selectCurrentAfterRefresh = true;
            refresh();
            return;
        }
        status = filteredResults.length + " clipboard entries";
    }
    function applyHistory(id, history) {
        if (id !== activeHistoryQueryId)
            return;
        historyRevision = Number(history.revision);
        pendingHistoryEntries = pendingHistoryEntries.concat(history.entries || []);
        if (history.has_more && pendingHistoryEntries.length < historySearchLimit) {
            backend.query(id, "", activeHistoryGeneration, historyPageSize,
                pendingHistoryEntries.length);
            return;
        }
        const entries = pendingHistoryEntries;
        activeHistoryQueryId = "";
        pendingHistoryEntries = [];
        applyProviderQuery(id, clipboardProvider.resultsForEntries(entries));
        selectCurrentEntry(history.current || null);
        status = entries.length + " clipboard entries"
            + (history.has_more ? " · search limited to recent entries" : "");
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
        if (historyRevision >= 0 && Number(revision) === historyRevision)
            return;
        scheduleRefresh();
    }
    function actionEntry() {
        return Flow.detailedEntry(
            selectedEntry, detailState.value, detailState.replacedSourceIds);
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
    function copySelected() { runAction("copy"); }
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
    function pasteImageAsFile() { runAction("image-as-file"); }
    function annotateImage() { runAction("annotate"); }
    function openUrl() { runAction("open-url"); }
    function requestDelete() { if (selectedEntry) deleteConfirmationOpen = true; }
    function cancelDelete() { deleteConfirmationOpen = false; }
    function confirmDelete() { deleteConfirmationOpen = false; runAction("delete"); }
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
    function finishScreenshot() {
        screenshotInFlight = false;
        selectCurrentAfterRefresh = true;
        scheduleRefresh();
    }
    function finishAnnotate() {
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
            paste: finishPaste, "image-as-file": finishPaste,
            wipe: finishWipe, "delete": finishDelete, screenshot: finishScreenshot,
            annotate: finishAnnotate, copy: scheduleRefresh,
            favorite: scheduleRefresh, unfavorite: scheduleRefresh
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
    function requestWipe() { if (!actionInFlight) backend.prepareWipe(); }
    function applyWipeChallenge(challenge) { wipeChallenge = challenge; }
    function cancelWipe() { wipeChallenge = null; }
    function confirmWipe() {
        if (!wipeChallenge)
            return;
        actionInFlight = true;
        backend.commitWipe(wipeChallenge.id);
    }
    function openDetails() {
        if (!hasSelection)
            return;
        detailsOpen = true;
        detailState.load();
    }
    function closeDetails() { detailsOpen = false; }
    function toggleDetails() { detailsOpen ? closeDetails() : openDetails(); }
    function isActionRequest(id) {
        return id.indexOf("action-") === 0 || id.indexOf("wipe-") === 0
            || id.indexOf("edit-") === 0 || id === "capture-screenshot";
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
            if (id === "capture-screenshot")
                screenshotInFlight = false;
        }
        if (isActiveQuery(id)) {
            activeHistoryQueryId = "";
            pendingHistoryEntries = [];
            clearProviderResults();
            status = message;
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
    function handleTransportFailure(message) {
        clearProviderResults();
        detailState.clear();
        actionInFlight = false;
        screenshotInFlight = false;
        activeAction = "";
        activeOperationId = "";
        activeHistoryQueryId = "";
        revisionRequestId = "";
        historyRevision = -1;
        pendingHistoryEntries = [];
        status = message;
    }
    onSelectedResultChanged: {
        deleteConfirmationOpen = false;
        detailState.selectionChanged();
    }
    ClipboardBackend { id: backend; controller: clipboardController }
    ClipboardDetailsController {
        id: detailsModel
        controller: clipboardController
        daemonBackend: backend
    }
}
