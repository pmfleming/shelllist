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
    property bool pasteAfterSave
    property string editId
    property string editDraft
    property string committedDraft
    property int sequence
    property string entryId
    property var replacedSourceIds: []
    property double entryRevision: -1
    property string requestId
    property string thumbnailRequestId
    readonly property var selectedEntry: controller.selectedEntry
    readonly property string selectedEntryId: selectedEntry ? selectedEntry.id : ""
    readonly property bool directTextEdit: !!selectedEntry && selectedEntry.kind === "text"
    readonly property bool editOperationActive: editing || editBeginPending || saveInFlight

    function beginEdit(entry: var): bool {
        const target = entry || selectedEntry;
        if (!target || controller.actionInFlight || editOperationActive)
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
    function setEditorFocused(focused: bool): void {
        editorFocused = focused;
        if (focused && directTextEdit)
            beginEdit();
    }
    function updateEditDraft(text: string): void {
        if (!editing || !editIsDirect || saveInFlight || text === editDraft)
            return;
        editDraft = text;
        editDirty = true;
        autoSaveTimer.restart();
    }
    function applyEdit(id: string, edit: var): void {
        if (id === "edit-begin") {
            editBeginPending = false;
            editId = edit.id || ""; editDraft = edit.value || "";
            editDirty = false;
            editing = editId.length > 0;
        } else if (id === "edit-cancel") {
            editBeginPending = false;
            editing = false; editIsDirect = false; editId = ""; editDirty = false;
        }
    }
    function commitEdit(): bool {
        if (!editing || editId.length === 0 || saveInFlight || (editIsDirect && !editDirty))
            return false;
        autoSaveTimer.stop();
        committedDraft = editDraft;
        savingDirectEdit = editIsDirect;
        saveInFlight = true;
        editDirty = false;
        controller.actionInFlight = true; controller.activeAction = "edit";
        if (savingDirectEdit)
            controller.status = pasteAfterSave ? "Saving clipboard text before pasting…" : "Saving clipboard text…";
        daemonBackend.commitEdit(editId, committedDraft);
        return true;
    }
    function preparePaste(): bool {
        if (!directTextEdit || entryId.length === 0 || selectedEntryId !== entryId)
            return false;
        if (saveInFlight) {
            pasteAfterSave = true;
            controller.status = "Saving clipboard text before pasting…";
            return true;
        }
        if (!editing || !editDirty)
            return false;
        pasteAfterSave = true;
        if (!commitEdit())
            pasteAfterSave = false;
        return true;
    }
    function finishDirectEdit(): void {
        editorFocused = false;
        if (!saveInFlight && !commitEdit())
            cancelEdit();
    }
    function cancelEdit(): void {
        autoSaveTimer.stop();
        if (editId.length > 0)
            daemonBackend.cancelEdit(editId);
        editBeginPending = false; saveInFlight = false; savingDirectEdit = false; pasteAfterSave = false;
        editing = false; editIsDirect = false; editId = ""; editDraft = ""; editDirty = false;
    }
    function resetCommitState(): void {
        controller.actionInFlight = false; controller.activeAction = "";
        saveInFlight = false; savingDirectEdit = false; pasteAfterSave = false;
        editing = false; editIsDirect = false; editId = ""; editDirty = false;
    }
    function rememberReplacedEntry(sourceEntryId: string, replacementId: string): void {
        if (replacementId !== sourceEntryId && replacedSourceIds.indexOf(sourceEntryId) < 0)
            replacedSourceIds = replacedSourceIds.concat([sourceEntryId]);
    }
    function selectionTracksEdit(sourceEntryId: string, replacementId: string): bool {
        return editorFocused
            && (selectedEntryId === sourceEntryId || selectedEntryId === replacementId);
    }
    function applyDirectEditCommit(nextValue: var, entry: var, sourceEntryId: string, shouldPaste: bool): void {
        value = nextValue;
        entryId = entry.id;
        entryRevision = entry.revision;
        rememberReplacedEntry(sourceEntryId, entry.id);
        editDraft = nextValue.text === null || nextValue.text === undefined
            ? committedDraft : nextValue.text;
        controller.status = "Clipboard text saved";
        controller.scheduleRefresh();
        if (shouldPaste) {
            editorFocused = false;
            controller.runAction("paste", undefined, entry);
            return;
        }
        if (selectionTracksEdit(sourceEntryId, entry.id))
            Qt.callLater(function () { detailsController.beginEdit(entry); });
    }
    function applyEditCommit(nextValue: var): void {
        const entry = nextValue ? nextValue.entry : null;
        const sourceEntryId = entryId;
        const wasDirect = savingDirectEdit;
        const shouldPaste = wasDirect && pasteAfterSave;
        resetCommitState();
        if (wasDirect && entry) {
            applyDirectEditCommit(nextValue, entry, sourceEntryId, shouldPaste);
            return;
        }
        value = null;
        controller.status = "Clipboard entry updated";
        controller.scheduleRefresh();
    }
    function selectedEntryMatches(id: string, revision: var): bool {
        return !!selectedEntry && selectedEntry.id === id && selectedEntry.revision === revision;
    }
    function clear(): void {
        autoSaveTimer.stop();
        editing = false; editBeginPending = false; editDirty = false; editIsDirect = false; editorFocused = false;
        saveInFlight = false; savingDirectEdit = false; pasteAfterSave = false;
        editId = ""; editDraft = ""; committedDraft = "";
        value = null; thumbnail = null; error = ""; loading = false;
        entryId = ""; replacedSourceIds = []; entryRevision = -1;
        requestId = ""; thumbnailRequestId = "";
    }
    function alreadyLoaded(entry: var): bool {
        return (loading && entryId === entry.id && entryRevision === entry.revision)
            || (value && value.entry.id === entry.id && value.entry.revision === entry.revision);
    }
    function request(entry: var, suffix: string): void {
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
    function load(): void {
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
    function scheduleLoad(): void { if (controller.detailsOpen) loadTimer.restart(); }
    function selectionChanged(): void {
        if (editOperationActive && selectedEntryId === entryId)
            return;
        if (editing)
            editIsDirect && editDirty ? commitEdit() : cancelEdit();
        scheduleLoad();
    }
    function applyDetails(id: string, nextValue: var): void {
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
    function applyThumbnail(id: string, nextValue: var): void {
        if (id !== thumbnailRequestId)
            return;
        thumbnailRequestId = "";
        if (selectedEntryMatches(entryId, entryRevision)
                && nextValue.entry_id === entryId && nextValue.revision === entryRevision)
            thumbnail = nextValue;
    }
    function handleFailure(id: string, message: string): bool {
        if (id === "edit-begin") {
            editBeginPending = false;
            editIsDirect = false;
        }
        if (id === "edit-commit") {
            saveInFlight = false; savingDirectEdit = false; pasteAfterSave = false;
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
