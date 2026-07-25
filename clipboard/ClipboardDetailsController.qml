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
    property string editId
    property string editDraft
    property int editMaxBytes
    property int sequence
    property string entryId
    property var entryRevision
    property string requestId
    property string thumbnailRequestId
    readonly property var selectedEntry: controller.selectedEntry

    function beginEdit() {
        if (selectedEntry && !controller.actionInFlight)
            daemonBackend.beginEdit(selectedEntry);
    }
    function applyEdit(id, edit) {
        if (id === "edit-begin") {
            editId = edit.id || ""; editDraft = edit.value || ""; editMaxBytes = edit.max_bytes || 0;
            editing = editId.length > 0;
        } else if (id === "edit-cancel") {
            editing = false; editId = "";
        }
    }
    function commitEdit() {
        if (!editing || editId.length === 0)
            return;
        controller.actionInFlight = true; controller.activeAction = "edit";
        daemonBackend.commitEdit(editId, editDraft);
    }
    function cancelEdit() {
        if (editId.length > 0)
            daemonBackend.cancelEdit(editId);
        editing = false; editId = ""; editDraft = "";
    }
    function applyEditCommit() {
        controller.actionInFlight = false; controller.activeAction = "";
        editing = false; editId = ""; value = null;
        controller.status = "Clipboard entry updated";
        controller.scheduleRefresh();
    }
    function selectedEntryMatches(id, revision) {
        return !!selectedEntry && selectedEntry.id === id && selectedEntry.revision === revision;
    }
    function clear() {
        editing = false; editId = ""; editDraft = ""; editMaxBytes = 0;
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
        if (editing)
            cancelEdit();
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
        if (id === "edit-commit") {
            editing = false; editId = "";
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
}
