import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

Ui.ChooserController {
    id: controller
    property string status: "Loading clipboard history…"
    property string sessionId: ""
    property bool targetAvailable: false
    property bool actionInFlight: false
    property bool screenshotInFlight: false
    property string activeAction: ""
    property string activeOperationId: ""
    property var settings: ({ max_entries: 750, max_favorites: 100, max_entry_bytes: 16777216, capture_paused: false, private_mode: false })
    property var wipeChallenge: null
    property bool deleteConfirmationOpen: false
    property bool detailsLoading: false
    property string detailsError: ""
    property var details: null
    property var thumbnail: null
    property bool editingText: false
    property string editId: ""
    property string editDraft: ""
    property int editMaxBytes: 0
    property var currentEntry: null
    property int detailSequence: 0
    property string detailsEntryId: ""
    property var detailsEntryRevision: null
    property string activeDetailsRequestId: ""
    property string activeThumbnailRequestId: ""
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    readonly property var filteredResults: results.visibleResults
    readonly property var filteredResultsModel: results.visibleModel
    readonly property var selectedResult: results.selected()
    readonly property var selectedEntry: selectedResult ? selectedResult.payload : null
    readonly property alias navigation: navigationModel
    hasSelection: !!selectedResult
    selectionModel: results

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
        if (editingText)
            cancelEdit();
        clearDetails();
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
        scheduleDetailsLoad();
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
    function imageAsFile() { runAction("image-as-file"); }
    function annotateImage() { runAction("annotate"); }
    function openUrl() { runAction("open-url"); }
    function openFile(index) { runAction("open-file", index || 0); }
    function revealFile(index) { runAction("reveal-file", index || 0); }
    function beginEdit() {
        if (selectedEntry && !actionInFlight)
            backend.beginEdit(selectedEntry);
    }
    function applyEdit(id, edit) {
        if (id === "edit-begin") {
            editId = edit.id || "";
            editDraft = edit.value || "";
            editMaxBytes = edit.max_bytes || 0;
            editingText = editId.length > 0;
        } else if (id === "edit-cancel") {
            editingText = false;
            editId = "";
        }
    }
    function commitEdit() {
        if (editingText && editId.length > 0) {
            actionInFlight = true;
            activeAction = "edit";
            backend.commitEdit(editId, editDraft);
        }
    }
    function cancelEdit() {
        if (editId.length > 0)
            backend.cancelEdit(editId);
        editingText = false;
        editId = "";
        editDraft = "";
    }
    function applyEditCommit(entry) {
        actionInFlight = false;
        activeAction = "";
        editingText = false;
        editId = "";
        status = "Clipboard entry updated";
        details = null;
        scheduleRefresh();
    }
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
        const completions = ({
            paste: function () { if (operation.status === "paste-prepared") backend.hideSession(sessionId); },
            wipe: finishWipe, "delete": finishDelete, screenshot: finishScreenshot,
            copy: scheduleRefresh, "image-as-file": scheduleRefresh,
            favorite: scheduleRefresh, unfavorite: scheduleRefresh, "pin-current": scheduleRefresh
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
        loadDetails();
    }
    function closeDetails() { detailsOpen = false; }
    function toggleDetails() { detailsOpen ? closeDetails() : openDetails(); }
    function scheduleDetailsLoad() {
        if (detailsOpen)
            detailsTimer.restart();
    }
    function selectedEntryMatches(id, revision) {
        return !!selectedEntry && selectedEntry.id === id && selectedEntry.revision === revision;
    }
    function clearDetails() {
        editingText = false;
        editId = "";
        editDraft = "";
        editMaxBytes = 0;
        details = null;
        thumbnail = null;
        detailsError = "";
        detailsLoading = false;
        detailsEntryId = "";
        detailsEntryRevision = null;
        activeDetailsRequestId = "";
        activeThumbnailRequestId = "";
    }
    function loadDetails() {
        const entry = selectedEntry;
        if (!entry) {
            clearDetails();
            return;
        }
        if (detailsLoading && detailsEntryId === entry.id && detailsEntryRevision === entry.revision)
            return;
        if (details && details.entry.id === entry.id && details.entry.revision === entry.revision)
            return;
        clearDetails();
        detailsEntryId = entry.id;
        detailsEntryRevision = entry.revision;
        detailsLoading = true;
        detailSequence += 1;
        const suffix = "-" + detailSequence;
        activeDetailsRequestId = "details" + suffix;
        if (!backend.details(activeDetailsRequestId, entry)) {
            activeDetailsRequestId = "";
            detailsLoading = false;
            detailsError = "Could not request clipboard entry details";
            return;
        }
        if (entry.kind === "image") {
            activeThumbnailRequestId = "thumbnail" + suffix;
            if (!backend.thumbnail(activeThumbnailRequestId, entry))
                activeThumbnailRequestId = "";
        }
    }
    function applyDetails(id, value) {
        if (id !== activeDetailsRequestId)
            return;
        activeDetailsRequestId = "";
        detailsLoading = false;
        if (!selectedEntryMatches(detailsEntryId, detailsEntryRevision)) {
            scheduleDetailsLoad();
            return;
        }
        if (!value.entry || value.entry.id !== detailsEntryId
                || value.entry.revision !== detailsEntryRevision) {
            detailsError = "Clipboard entry changed while loading";
            scheduleDetailsLoad();
            return;
        }
        details = value;
        detailsError = "";
    }
    function applyThumbnail(id, value) {
        if (id !== activeThumbnailRequestId)
            return;
        activeThumbnailRequestId = "";
        if (selectedEntryMatches(detailsEntryId, detailsEntryRevision)
                && value.entry_id === detailsEntryId && value.revision === detailsEntryRevision)
            thumbnail = value;
    }
    function handleFailure(id, message) {
        if (id.indexOf("action-") === 0 || id.indexOf("wipe-") === 0 || id.indexOf("edit-") === 0
                || id === "capture-screenshot") {
            actionInFlight = false;
            activeAction = "";
            activeOperationId = "";
            if (id === "capture-screenshot")
                screenshotInFlight = false;
            if (id === "edit-commit") {
                editingText = false;
                editId = "";
            }
        }
        if (id === results.activeQueryId) {
            results.clear();
            status = message;
        } else if (id === activeDetailsRequestId) {
            activeDetailsRequestId = "";
            detailsLoading = false;
            detailsError = message;
        } else if (id === activeThumbnailRequestId) {
            activeThumbnailRequestId = "";
            thumbnail = null;
        } else if (id.indexOf("details-") !== 0 && id.indexOf("thumbnail-") !== 0) {
            status = message;
        }
    }
    function handleTransportFailure(message) {
        results.clear();
        clearDetails();
        actionInFlight = false;
        screenshotInFlight = false;
        activeAction = "";
        activeOperationId = "";
        status = message;
    }
    Timer { id: searchTimer; interval: 120; repeat: false; onTriggered: if (controller.uiActive) controller.refresh() }
    Timer { id: refreshTimer; interval: 90; repeat: false; onTriggered: if (controller.uiActive) controller.refresh() }
    Timer { id: detailsTimer; interval: 0; repeat: false; onTriggered: controller.loadDetails() }

    onFilterTextChanged: if (uiActive) searchTimer.restart()
    onSelectedResultChanged: {
        deleteConfirmationOpen = false;
        if (editingText) cancelEdit();
        scheduleDetailsLoad();
    }
    Ui.ResultNavigation {
        id: navigationModel
        controller: controller
        primaryEnabled: controller.hasSelection && controller.selectedEntry.kind !== "binary"
            && !controller.actionInFlight && !controller.wipeChallenge
        closeEnabled: false
    }
    Core.ProviderRegistry {
        id: providers
        ClipboardProvider { id: provider; controller: controller }
    }
    Core.ResultStore { id: results; registry: providers }
    ClipboardBackend { id: backend; controller: controller }
}
