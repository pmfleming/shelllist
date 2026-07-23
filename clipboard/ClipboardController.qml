import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

Item {
    id: controller

    property bool uiActive: false
    property string currentWorkspaceId: ""
    property string status: "Loading clipboard history…"
    property string sessionId: ""
    property bool targetAvailable: false
    property bool actionInFlight: false
    property string activeAction: ""
    property string activeOperationId: ""
    property var settings: ({ max_entries: 750, max_favorites: 100, max_entry_bytes: 16777216, capture_paused: false, private_mode: false })
    property var wipeChallenge: null
    property bool deleteConfirmationOpen: false
    property bool detailsOpen: false
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
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    readonly property var filteredResults: results.visibleResults
    readonly property var filteredResultsModel: results.visibleModel
    readonly property var selectedResult: results.selected()
    readonly property var selectedEntry: selectedResult ? selectedResult.payload : null
    readonly property bool hasSelection: !!selectedResult
    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) { return key.indexOf("query-") === 0; })
    readonly property int closedWindowWidth: Ui.Theme.popupClosedWidth
    readonly property int openWindowWidth: Ui.Theme.popupOpenWidth
    readonly property int surfaceWindowWidth: openWindowWidth
    readonly property int contentMargin: Ui.Theme.contentMargin
    readonly property int contentVerticalMargin: Ui.Theme.contentVerticalMargin
    readonly property int listPaneWidth: closedWindowWidth - 2 * contentMargin
    readonly property int detailsGapWidth: Ui.Theme.detailsGapWidth
    readonly property real detailsRenderCutoff: 0.025
    property real detailsExpansionProgress: detailsOpen ? 1 : 0
    readonly property real detailsPaintProgress: (!detailsOpen && detailsExpansionProgress <= detailsRenderCutoff) ? 0 : detailsExpansionProgress
    readonly property real detailsPaneFullWidth: openWindowWidth - closedWindowWidth - detailsGapWidth
    readonly property real detailsPaneWidth: detailsPaintProgress * detailsPaneFullWidth
    readonly property real detailsPaneGapWidth: detailsPaintProgress * detailsGapWidth
    readonly property bool detailsRendered: detailsOpen || detailsExpansionProgress > detailsRenderCutoff
    readonly property int currentWindowWidth: Math.round(closedWindowWidth + detailsPaintProgress * (openWindowWidth - closedWindowWidth))

    signal focusSearchRequested
    signal focusListTopRequested
    signal hideRequested

    function activateUi(workspaceId) {
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
        backend.beginSession();
        backend.getSettings();
        refresh();
    }
    function deactivateUi() {
        if (sessionId.length > 0)
            backend.endSession(sessionId);
        uiActive = false;
        sessionId = "";
        targetAvailable = false;
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
        if (detailsOpen)
            loadDetails();
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
    function copySelected() { runAction("copy"); }
    function pasteSelected() { runAction("paste"); }
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
    function applyOperation(id, operation) {
        actionInFlight = operation.status === "started";
        activeAction = actionInFlight ? operation.action : "";
        activeOperationId = actionInFlight ? (operation.id || "") : "";
        status = operation.message || "Clipboard operation completed";
        if (operation.action === "paste" && operation.status === "paste-prepared") {
            backend.hideSession(sessionId);
            return;
        }
        if (operation.action === "wipe") {
            wipeChallenge = null;
            closeDetails();
            scheduleRefresh();
        } else if (["copy", "image-as-file", "delete", "favorite", "unfavorite", "pin-current"].indexOf(operation.action) >= 0) {
            if (operation.action === "delete") closeDetails();
            scheduleRefresh();
        }
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
    function clearDetails() {
        editingText = false;
        editId = "";
        editDraft = "";
        editMaxBytes = 0;
        details = null;
        thumbnail = null;
        detailsError = "";
        detailsLoading = false;
    }
    function loadDetails() {
        clearDetails();
        if (!selectedEntry)
            return;
        detailsLoading = true;
        detailSequence += 1;
        const suffix = "-" + detailSequence;
        backend.details("details" + suffix, selectedEntry);
        if (selectedEntry.kind === "image")
            backend.thumbnail("thumbnail" + suffix, selectedEntry);
    }
    function applyDetails(id, value) {
        if (id.indexOf("details-") !== 0 || !selectedEntry || value.entry.id !== selectedEntry.id)
            return;
        details = value;
        detailsLoading = false;
        detailsError = "";
    }
    function applyThumbnail(id, value) {
        if (id.indexOf("thumbnail-") !== 0 || !selectedEntry || value.entry_id !== selectedEntry.id)
            return;
        thumbnail = value;
    }
    function handleFailure(id, message) {
        if (id.indexOf("action-") === 0 || id.indexOf("wipe-") === 0 || id.indexOf("edit-") === 0) {
            actionInFlight = false;
            activeAction = "";
            activeOperationId = "";
            if (id === "edit-commit") {
                editingText = false;
                editId = "";
            }
        }
        if (id === results.activeQueryId) {
            results.clear();
            status = message;
        } else if (id.indexOf("details-") === 0 || id.indexOf("thumbnail-") === 0) {
            detailsLoading = false;
            detailsError = message;
        } else {
            status = message;
        }
    }
    function handleTransportFailure(message) {
        results.clear();
        clearDetails();
        status = message;
    }
    function moveSelection(delta) { results.move(delta); }

    Timer { id: searchTimer; interval: 120; repeat: false; onTriggered: if (controller.uiActive) controller.refresh() }
    Timer { id: refreshTimer; interval: 90; repeat: false; onTriggered: if (controller.uiActive) controller.refresh() }

    onFilterTextChanged: if (uiActive) searchTimer.restart()
    onSelectedResultChanged: {
        deleteConfirmationOpen = false;
        if (editingText) cancelEdit();
        if (detailsOpen) loadDetails();
    }
    Behavior on detailsExpansionProgress {
        enabled: !Ui.Theme.noAnimations
        NumberAnimation { duration: Ui.Theme.animationNormal; easing.type: Ui.Theme.easingGentle }
    }

    Core.ProviderRegistry {
        id: providers
        ClipboardProvider { id: provider; controller: controller }
    }
    Core.ResultStore { id: results; registry: providers }
    ClipboardBackend { id: backend; controller: controller }
}
