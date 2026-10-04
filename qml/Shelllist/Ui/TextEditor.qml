import QtQuick

// Native multiline editing. A lease-owning domain can allow focus before its
// editor becomes writable; no draft/value is owned by presentation memory.
TextEdit {
    id: editor
    property bool browseFocused: false
    property bool editingAllowed: !readOnly
    signal edited(string value)
    signal editFinished(bool saved)
    readonly property FieldEditSession editSession: FieldEditSession {
        owner: editor
        available: editor.enabled && editor.editingAllowed
        multiline: true
        valueProperty: "text"
        value: editor.text
        onRestoreRequested: function (value) { editor.text = value; }
        onPublishRequested: function (value) { editor.edited(value); }
        onFinished: function (saved) { editor.editFinished(saved); }
    }
    FocusRing {
        active: editor.activeFocus || editor.browseFocused
        editing: editor.editSession.active
    }
    Keys.onPressed: function (event) { editSession.handleKey(event); }
    signal selectionChanged
    onCursorPositionChanged: selectionChanged()
    onSelectionStartChanged: selectionChanged()
    onSelectionEndChanged: selectionChanged()

    function selectionState(): var {
        return {cursor: cursorPosition, anchor: cursorPosition === selectionStart ? selectionEnd : selectionStart};
    }
    function restoreSelection(state: var): void {
        if (!state || !Number.isFinite(state.cursor) || !Number.isFinite(state.anchor))
            return;
        select(Math.max(0, Math.min(text.length, state.anchor)), Math.max(0, Math.min(text.length, state.cursor)));
    }
}
