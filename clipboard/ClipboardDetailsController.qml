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
    property string editError: ""
    property var editTarget: null
    property var editPreview: null
    property bool retryingEdit: false
    property var failedDrafts: ({})
    property var pendingCommit: null
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
        editTarget = target;
        editPreview = value;
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
        if (editError.length === 0)
            autoSaveTimer.restart();
        else
            rememberFailedDraft();
    }
    function rememberFailedDraft(): void {
        if (!editTarget || !editDirty || editError.length === 0)
            return;
        const next = Object.assign({}, failedDrafts);
        next[editTarget.id] = {target: editTarget, preview: editPreview, draft: editDraft, error: editError, direct: editIsDirect};
        failedDrafts = next;
    }
    function forgetFailedDraft(): void {
        if (!editTarget)
            return;
        const next = Object.assign({}, failedDrafts);
        delete next[editTarget.id];
        failedDrafts = next;
    }
    function restoreFailedDraft(entry: var): bool {
        const saved = failedDrafts[entry.id];
        if (!saved)
            return false;
        editTarget = saved.target;
        editPreview = saved.preview;
        value = saved.preview;
        entryId = saved.target.id;
        entryRevision = saved.target.revision;
        editDraft = saved.draft;
        editError = saved.error;
        editIsDirect = saved.direct;
        editing = true;
        editDirty = true;
        return true;
    }
    function retryEdit(): bool {
        if (!editTarget || editError.length === 0 || saveInFlight || editBeginPending || controller.actionInFlight)
            return false;
        autoSaveTimer.stop();
        // Commit consumes its lease even on failure. Obtain a fresh lease for
        // the ORIGINAL revision; never silently overwrite a newer entry.
        retryingEdit = true;
        editBeginPending = true;
        if (!daemonBackend.beginEdit(editTarget)) {
            retryingEdit = false;
            editBeginPending = false;
            return false;
        }
        return true;
    }
    function discardFailedEdit(): void {
        if (saveInFlight || editBeginPending)
            return;
        cancelEdit();
        clearPreview();
        scheduleLoad();
    }
    function applyEdit(id: string, edit: var): void {
        if (id !== "edit-begin" || !editBeginPending)
            return;
        editBeginPending = false;
        editId = edit.id || "";
        if (retryingEdit) {
            retryingEdit = false;
            if (!editId) {
                handleFailure("edit-begin", "Could not renew the clipboard edit session");
                return;
            }
            editError = "";
            commitEdit();
            return;
        }
        editDraft = edit.value || "";
        editDirty = false;
        editing = editId.length > 0;
        // Cancellation is applied locally; late cancel replies must not reset
        // a different edit session opened in the meantime.
    }
    function commitEdit(): bool {
        if (!editing || editId.length === 0 || saveInFlight || editError.length > 0 || (editIsDirect && !editDirty))
            return false;
        autoSaveTimer.stop();
        committedDraft = editDraft;
        savingDirectEdit = editIsDirect;
        pendingCommit = {target: editTarget, preview: editPreview, draft: committedDraft, direct: editIsDirect};
        saveInFlight = true;
        editDirty = false;
        controller.actionInFlight = true;
        controller.activeAction = "edit";
        if (savingDirectEdit)
            controller.status = pasteAfterSave ? "Saving clipboard text before pasting…" : "Saving clipboard text…";
        if (daemonBackend.commitEdit(editId, committedDraft))
            return true;
        controller.actionInFlight = false;
        controller.activeAction = "";
        handleFailure("edit-commit", "Could not send clipboard edit; retry when the service is ready");
        return false;
    }
    function preparePaste(): bool {
        if (!directTextEdit || entryId.length === 0 || selectedEntryId !== entryId)
            return false;
        if (editError.length > 0) {
            controller.status = "Retry or discard the unsaved clipboard draft before pasting";
            return true;
        }
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
        if (editError.length > 0 || editBeginPending)
            return;
        if (!saveInFlight && !commitEdit())
            cancelEdit();
    }
    function cancelEdit(): void {
        forgetFailedDraft();
        editError = "";
        retryingEdit = false;
        autoSaveTimer.stop();
        if (editId.length > 0)
            daemonBackend.cancelEdit(editId);
        editBeginPending = false;
        saveInFlight = false;
        savingDirectEdit = false;
        pasteAfterSave = false;
        editing = false;
        editIsDirect = false;
        editId = "";
        editDraft = "";
        editDirty = false;
    }
    function resetCommitState(): void {
        controller.actionInFlight = false;
        controller.activeAction = "";
        saveInFlight = false;
        savingDirectEdit = false;
        pasteAfterSave = false;
        editing = false;
        editIsDirect = false;
        editId = "";
        editDirty = false;
    }
    function rememberReplacedEntry(sourceEntryId: string, replacementId: string): void {
        if (replacementId !== sourceEntryId && replacedSourceIds.indexOf(sourceEntryId) < 0)
            replacedSourceIds = replacedSourceIds.concat([sourceEntryId]);
    }
    function selectionTracksEdit(sourceEntryId: string, replacementId: string): bool {
        return editorFocused && (selectedEntryId === sourceEntryId || selectedEntryId === replacementId);
    }
    function applyDirectEditCommit(nextValue: var, entry: var, sourceEntryId: string, shouldPaste: bool): void {
        value = nextValue;
        entryId = entry.id;
        entryRevision = entry.revision;
        rememberReplacedEntry(sourceEntryId, entry.id);
        editDraft = nextValue.text === null || nextValue.text === undefined ? committedDraft : nextValue.text;
        controller.status = "Clipboard text saved";
        controller.scheduleRefresh();
        if (shouldPaste) {
            editorFocused = false;
            controller.runAction("paste", undefined, entry);
            return;
        }
        if (selectionTracksEdit(sourceEntryId, entry.id))
            Qt.callLater(function () {
                detailsController.beginEdit(entry);
            });
    }
    function applyEditCommit(nextValue: var): void {
        const sent = pendingCommit;
        pendingCommit = null;
        if (sent && sent.target && (!editTarget || editTarget.id !== sent.target.id)) {
            const next = Object.assign({}, failedDrafts);
            delete next[sent.target.id];
            failedDrafts = next;
            if (controller.activeAction === "edit") {
                controller.actionInFlight = false;
                controller.activeAction = "";
            }
            controller.scheduleRefresh();
            return;
        }
        const entry = nextValue ? nextValue.entry : null;
        const sourceEntryId = entryId;
        const wasDirect = savingDirectEdit;
        const shouldPaste = wasDirect && pasteAfterSave;
        forgetFailedDraft();
        editError = "";
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
    function cancelPreviewRequests(): void {
        if (requestId.length > 0)
            daemonBackend.cancelRequest(requestId);
        if (thumbnailRequestId.length > 0)
            daemonBackend.cancelRequest(thumbnailRequestId);
        requestId = "";
        thumbnailRequestId = "";
    }
    function clearPreview(): void {
        cancelPreviewRequests();
        value = null;
        thumbnail = null;
        error = "";
        loading = false;
        entryId = "";
        entryRevision = -1;
    }
    function preserveDraftOnDisconnect(message: string): void {
        if (pendingCommit)
            handleFailure("edit-commit", message);
        if (editing && editDirty) {
            editError = message;
            editId = "";
            rememberFailedDraft();
        }
    }
    function clear(): void {
        rememberFailedDraft();
        editError = "";
        editTarget = null;
        editPreview = null;
        retryingEdit = false;
        loadTimer.stop();
        autoSaveTimer.stop();
        cancelPreviewRequests();
        editing = false;
        editBeginPending = false;
        editDirty = false;
        editIsDirect = false;
        editorFocused = false;
        saveInFlight = false;
        savingDirectEdit = false;
        pasteAfterSave = false;
        editId = "";
        editDraft = "";
        committedDraft = "";
        value = null;
        thumbnail = null;
        error = "";
        loading = false;
        entryId = "";
        replacedSourceIds = [];
        entryRevision = -1;
    }
    function alreadyLoaded(entry: var): bool {
        return (loading && entryId === entry.id && entryRevision === entry.revision) || (value && value.entry.id === entry.id && value.entry.revision === entry.revision);
    }
    function request(entry: var, suffix: string): void {
        requestId = "details" + suffix;
        if (!daemonBackend.details(requestId, entry)) {
            requestId = "";
            loading = false;
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
        if (restoreFailedDraft(entry))
            return;
        entryId = entry.id;
        entryRevision = entry.revision;
        loading = true;
        sequence += 1;
        request(entry, "-" + sequence);
    }
    function scheduleLoad(): void {
        if (controller.detailsOpen)
            loadTimer.restart();
    }
    function selectionChanged(): void {
        if (editOperationActive && selectedEntryId === entryId)
            return;
        if (editing && editError.length > 0) {
            clear();
            scheduleLoad();
            return;
        }
        if (editing) {
            if (editIsDirect && editDirty) {
                commitEdit();
                cancelPreviewRequests();
                value = null;
                thumbnail = null;
                error = "";
                loading = false;
                return;
            }
            cancelEdit();
        }
        // Drop stale content immediately, but wait briefly before asking the
        // daemon so key-repeat navigation does not decode every image crossed.
        clearPreview();
        scheduleLoad();
    }
    function applyDetails(id: string, nextValue: var): void {
        if (id !== requestId)
            return;
        requestId = "";
        loading = false;
        if (!selectedEntryMatches(entryId, entryRevision)) {
            scheduleLoad();
            return;
        }
        if (!nextValue.entry || nextValue.entry.id !== entryId || nextValue.entry.revision !== entryRevision) {
            error = "Clipboard entry changed while loading";
            scheduleLoad();
            return;
        }
        value = nextValue;
        error = "";
    }
    function applyThumbnail(id: string, nextValue: var): void {
        if (id !== thumbnailRequestId)
            return;
        thumbnailRequestId = "";
        if (selectedEntryMatches(entryId, entryRevision) && nextValue.entry_id === entryId && nextValue.revision === entryRevision)
            thumbnail = nextValue;
    }
    function handleFailure(id: string, message: string): bool {
        if (id === "edit-begin") {
            editBeginPending = false;
            if (retryingEdit || editError.length > 0) {
                retryingEdit = false;
                editError = message;
                rememberFailedDraft();
                return false;
            }
            editIsDirect = false;
        }
        if (id === "edit-commit") {
            const sent = pendingCommit;
            pendingCommit = null;
            if (sent && sent.target && (!editTarget || editTarget.id !== sent.target.id)) {
                const next = Object.assign({}, failedDrafts);
                next[sent.target.id] = {target: sent.target, preview: sent.preview, draft: sent.draft, error: message, direct: sent.direct};
                failedDrafts = next;
                scheduleLoad();
                return false;
            }
            autoSaveTimer.stop();
            saveInFlight = false;
            savingDirectEdit = false;
            pasteAfterSave = false;
            editing = true;
            editId = "";
            editDirty = true;
            editError = message;
            rememberFailedDraft();
            if (editTarget && selectedEntryId !== editTarget.id)
                scheduleLoad();
        }
        if (id === requestId) {
            requestId = "";
            loading = false;
            error = message;
            return true;
        }
        if (id === thumbnailRequestId) {
            thumbnailRequestId = "";
            thumbnail = null;
            return true;
        }
        return id.indexOf("details-") === 0 || id.indexOf("thumbnail-") === 0;
    }
    Timer {
        id: loadTimer
        interval: 65
        repeat: false
        onTriggered: detailsController.load()
    }
    Timer {
        id: autoSaveTimer
        interval: 650
        repeat: false
        onTriggered: detailsController.commitEdit()
    }
}
