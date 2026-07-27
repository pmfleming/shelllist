import QtQuick
Item {
    id: detailsController
    required property ClipboardController controller
    required property ClipboardBackend daemonBackend
    property bool loading
    property string error
    property var value
    property var thumbnail
    property bool editing
    property bool editBeginPending
    property bool editDirty
    property bool editIsDirect
    property bool editorFocused
    property bool saveInFlight
    property bool savingDirectEdit
    property string editId
    property string editDraft
    property string committedDraft
    property int editMaxBytes
    property int sequence
    property string entryId
    property var entryRevision
    property string requestId
    property string thumbnailRequestId
    readonly property var selectedEntry: controller.selectedEntry
    readonly property bool directTextEdit: !!selectedEntry && selectedEntry.kind === "text"

    function beginEdit(entry) {
        const target = entry || selectedEntry;
        if (!target || controller.actionInFlight || editBeginPending || editing)
            return false;
        editBeginPending = true;
        editIsDirect = target.kind === "text";
        if (!daemonBackend.beginEdit(target)) {
            editBeginPending = false;
            editIsDirect = false;
            return false;
        }
        return true;
    }
    function requestDirectEdit() {
        if (directTextEdit)
            beginEdit();
    }
    function setEditorFocused(focused) {
        editorFocused = focused;
        if (focused)
            requestDirectEdit();
    }
    function updateEditDraft(text) {
        if (!editing || !editIsDirect || saveInFlight || text === editDraft)
            return;
        editDraft = text;
        editDirty = true;
        autoSaveTimer.restart();
    }
    function applyEdit(id, edit) {
        if (id === "edit-begin") {
            editBeginPending = false;
            editId = edit.id || ""; editDraft = edit.value || ""; editMaxBytes = edit.max_bytes || 0;
            editDirty = false;
            editing = editId.length > 0;
        } else if (id === "edit-cancel") {
            editBeginPending = false;
            editing = false; editIsDirect = false; editId = ""; editDirty = false;
        }
    }
    function commitEdit() {
        if (!editing || editId.length === 0 || saveInFlight || (editIsDirect && !editDirty))
            return false;
        autoSaveTimer.stop();
        committedDraft = editDraft;
        savingDirectEdit = editIsDirect;
        saveInFlight = true;
        editDirty = false;
        controller.actionInFlight = true; controller.activeAction = "edit";
        if (savingDirectEdit)
            controller.status = "Saving clipboard text…";
        daemonBackend.commitEdit(editId, committedDraft);
        return true;
    }
    function finishDirectEdit() {
        editorFocused = false;
        if (!commitEdit())
            cancelEdit();
    }
    function cancelEdit() {
        autoSaveTimer.stop();
        if (editId.length > 0)
            daemonBackend.cancelEdit(editId);
        editBeginPending = false; saveInFlight = false; savingDirectEdit = false;
        editing = false; editIsDirect = false; editId = ""; editDraft = ""; editDirty = false;
    }
    function applyEditCommit(entry) {
        const wasDirect = savingDirectEdit;
        controller.actionInFlight = false; controller.activeAction = "";
        saveInFlight = false; savingDirectEdit = false;
        editing = false; editIsDirect = false; editId = ""; editDirty = false;
        if (wasDirect) {
            if (value && value.entry && value.entry.id === entry.id) {
                value = Object.assign({}, value, { entry: entry, text: committedDraft });
                entryId = entry.id;
                entryRevision = entry.revision;
            }
            editDraft = committedDraft;
            controller.status = "Clipboard text saved";
            controller.scheduleRefresh();
            if (editorFocused && selectedEntry && selectedEntry.id === entry.id)
                Qt.callLater(function () { detailsController.beginEdit(entry); });
            return;
        }
        value = null;
        controller.status = "Clipboard entry updated";
        controller.scheduleRefresh();
    }
    function selectedEntryMatches(id, revision) {
        return !!selectedEntry && selectedEntry.id === id && selectedEntry.revision === revision;
    }
    function clear() {
        autoSaveTimer.stop();
        editing = false; editBeginPending = false; editDirty = false; editIsDirect = false; editorFocused = false;
        saveInFlight = false; savingDirectEdit = false;
        editId = ""; editDraft = ""; committedDraft = ""; editMaxBytes = 0;
        value = null; thumbnail = null; error = ""; loading = false;
        entryId = ""; entryRevision = null;
        requestId = ""; thumbnailRequestId = "";
    }
    function alreadyLoaded(entry) {
        return (loading && entryId === entry.id && entryRevision === entry.revision)
            || (value && value.entry.id === entry.id && value.entry.revision === entry.revision);
    }
    function request(entry, suffix) {
        requestId = "details" + suffix;
        if (!daemonBackend.details(requestId, entry)) {
            requestId = ""; loading = false;
            error = "Could not request clipboard entry details";
            return;
        }
        if (entry.kind !== "image")
            return;
        thumbnailRequestId = "thumbnail" + suffix;
        if (!daemonBackend.thumbnail(thumbnailRequestId, entry))
            thumbnailRequestId = "";
    }
    function load() {
        const entry = selectedEntry;
        if (!entry) {
            clear();
            return;
        }
        if (alreadyLoaded(entry))
            return;
        clear();
        entryId = entry.id; entryRevision = entry.revision; loading = true;
        sequence += 1;
        request(entry, "-" + sequence);
    }
    function scheduleLoad() { if (controller.detailsOpen) loadTimer.restart(); }
    function selectionChanged() {
        if ((editing || editBeginPending || saveInFlight)
                && selectedEntry && selectedEntry.id === entryId)
            return;
        if (editing)
            editIsDirect && editDirty ? commitEdit() : cancelEdit();
        scheduleLoad();
    }
    function applyDetails(id, nextValue) {
        if (id !== requestId)
            return;
        requestId = ""; loading = false;
        if (!selectedEntryMatches(entryId, entryRevision)) {
            scheduleLoad();
            return;
        }
        if (!nextValue.entry || nextValue.entry.id !== entryId
                || nextValue.entry.revision !== entryRevision) {
            error = "Clipboard entry changed while loading";
            scheduleLoad();
            return;
        }
        value = nextValue; error = "";
    }
    function applyThumbnail(id, nextValue) {
        if (id !== thumbnailRequestId)
            return;
        thumbnailRequestId = "";
        if (selectedEntryMatches(entryId, entryRevision)
                && nextValue.entry_id === entryId && nextValue.revision === entryRevision)
            thumbnail = nextValue;
    }
    function handleFailure(id, message) {
        if (id === "edit-begin") {
            editBeginPending = false;
            editIsDirect = false;
        }
        if (id === "edit-commit") {
            saveInFlight = false; savingDirectEdit = false;
            editing = false; editIsDirect = false; editId = ""; editDirty = false;
        }
        if (id === requestId) {
            requestId = ""; loading = false; error = message;
            return true;
        }
        if (id === thumbnailRequestId) {
            thumbnailRequestId = ""; thumbnail = null;
            return true;
        }
        return id.indexOf("details-") === 0 || id.indexOf("thumbnail-") === 0;
    }
    Timer { id: loadTimer; interval: 0; repeat: false; onTriggered: detailsController.load() }
    Timer { id: autoSaveTimer; interval: 650; repeat: false; onTriggered: detailsController.commitEdit() }
}
