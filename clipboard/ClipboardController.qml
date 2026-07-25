import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

Ui.ChooserController {
    id: clipboardController
    property string status: "Loading clipboard history…"
    property string sessionId: ""
    property bool targetAvailable: false
    property bool actionInFlight: false
    property bool screenshotInFlight: false
    property string activeAction: ""
    property string activeOperationId: ""
    property var settings: ({ max_entries: 750, max_favorites: 100, max_entry_bytes: 16777216, capture_paused: false, private_mode: false })
    property var wipeChallenge: null
    property bool deleteConfirmationOpen
    property var currentEntry: null
    readonly property alias detailState: detailsModel
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    readonly property var filteredResults: results.visibleResults
    readonly property var filteredResultsModel: results.visibleModel
    readonly property var selectedResult: results.selected()
    readonly property var selectedEntry: selectedResult ? selectedResult.payload : null
    hasSelection: !!selectedResult
    selectionModel: results
    navigationPrimaryEnabled: hasSelection && selectedEntry.kind !== "binary"
        && !actionInFlight && !wipeChallenge
    navigationCloseEnabled: false

    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) { return key.indexOf("query-") === 0; })
    signal hideRequested
    signal screenshotRequested

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        backend.beginSession();
        backend.getSettings();
        refresh();
    }
    function deactivateUi() {
        if (sessionId.length > 0)
            backend.endSession(sessionId);
        deactivateUiState();
        sessionId = "";
        targetAvailable = false;
        actionInFlight = false;
        screenshotInFlight = false;
        activeAction = "";
        activeOperationId = "";
        detailsOpen = false;
        if (detailState.editing)
            detailState.cancelEdit();
        detailState.clear();
    }
    function refresh() {
        status = "Loading clipboard history…";
        results.beginQuery(filterText, {}, [provider.providerId], 100);
    }
    function scheduleRefresh() { refreshTimer.restart(); }
    function requestHistory(id, text, generation, limit) { backend.query(id, text, generation, limit); }
    function cancelQuery(requestId) { backend.cancelRequest(requestId); }
    function applyHistory(id, history) {
        results.applyBatch({
            providerId: provider.providerId,
            queryId: id,
            replace: true,
            complete: true,
            results: provider.resultsForEntries(history.entries || [])
        });
        currentEntry = history.current || null;
        status = history.entries.length + " clipboard entries" + (history.has_more ? " · more available" : "");
        detailState.scheduleLoad();
    }
    function applySession(session) {
        sessionId = session.state === "hidden" || session.state === "ended" ? "" : (session.id || "");
        targetAvailable = session.target_available === true;
        if (session.state === "hidden")
            hideRequested();
    }
    function runAction(actionName, fileIndex) {
        if (!selectedEntry || actionInFlight)
            return;
        actionInFlight = true;
        activeAction = actionName;
        backend.action("action-" + actionName, selectedEntry, actionName, sessionId, fileIndex);
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
    function pasteSelected() { runAction("paste"); }
    function primarySelected() {
        if (!selectedEntry || selectedEntry.kind === "binary" || actionInFlight || wipeChallenge)
            return false;
        pasteSelected();
        return true;
    }
    function pasteImageAsFile() { runAction("image-as-file"); }
    function annotateImage() { runAction("annotate"); }
    function openUrl() { runAction("open-url"); }
    function openFile(index) { runAction("open-file", index || 0); }
    function revealFile(index) { runAction("reveal-file", index || 0); }
    function toggleFavorite() { runAction(selectedEntry && selectedEntry.favorite ? "unfavorite" : "favorite"); }
    function pinCurrent() { runAction("pin-current"); }
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
    function toggleCapturePaused(privateMode) {
        if (!actionInFlight)
            backend.setPaused(!settings.capture_paused, privateMode === true);
    }
    function cycleRetention() {
        const next = settings.max_entries >= 750 ? 250 : 750;
        backend.updateSettings({ max_entries: next });
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
        scheduleRefresh();
    }
    function applyOperation(id, operation) {
        actionInFlight = operation.status === "started";
        activeAction = actionInFlight ? operation.action : "";
        activeOperationId = actionInFlight ? (operation.id || "") : "";
        status = operation.message || "Clipboard operation completed";
        if (actionInFlight) return;
        const finishPaste = function () {
            if (operation.status === "paste-prepared")
                backend.hideSession(sessionId);
            else if (operation.action === "image-as-file")
                scheduleRefresh();
        };
        const completions = ({
            paste: finishPaste, "image-as-file": finishPaste,
            wipe: finishWipe, "delete": finishDelete, screenshot: finishScreenshot,
            copy: scheduleRefresh, favorite: scheduleRefresh,
            unfavorite: scheduleRefresh, "pin-current": scheduleRefresh
        });
        if (completions[operation.action]) completions[operation.action]();
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
        if (isActionRequest(id)) {
            actionInFlight = false;
            activeAction = "";
            activeOperationId = "";
            if (id === "capture-screenshot")
                screenshotInFlight = false;
        }
        if (id === results.activeQueryId) {
            results.clear();
            status = message;
        } else if (!detailState.handleFailure(id, message)) {
            status = message;
        }
    }
    function handleTransportFailure(message) {
        results.clear();
        detailState.clear();
        actionInFlight = false;
        screenshotInFlight = false;
        activeAction = "";
        activeOperationId = "";
        status = message;
    }
    Timer { id: searchTimer; interval: 120; repeat: false; onTriggered: if (clipboardController.uiActive) clipboardController.refresh() }
    Timer { id: refreshTimer; interval: 90; repeat: false; onTriggered: if (clipboardController.uiActive) clipboardController.refresh() }
    onFilterTextChanged: if (uiActive) searchTimer.restart()
    onSelectedResultChanged: {
        deleteConfirmationOpen = false;
        detailState.selectionChanged();
    }
    Core.ProviderRegistry {
        id: providers
        ClipboardProvider { id: provider; controller: clipboardController }
    }
    Core.ResultStore { id: results; registry: providers }
    ClipboardBackend { id: backend; controller: clipboardController }
    ClipboardDetailsController {
        id: detailsModel
        controller: clipboardController
        daemonBackend: backend
    }
}
