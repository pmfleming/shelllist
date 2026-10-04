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
        value: editor.text
        onRestoreRequested: function (value) { editor.text = value; }
        onPublishRequested: function (value) { editor.edited(value); }
        onFinished: function (saved) { editor.editFinished(saved); }
    }
    FocusRing {
        active: editor.activeFocus || editor.browseFocused
        editing: editor.editSession.active
    }
    Keys.onPressed: function (event) {
        const navigation = editSession.navigation;
        if (!navigation || !editSession.active || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            return;
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && event.modifiers === Qt.NoModifier)
            navigation.saveEditor();
        else if (event.key === Qt.Key_Escape)
            navigation.retreat();
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
            navigation.cycleFocus(event.key === Qt.Key_Backtab || !!(event.modifiers & Qt.ShiftModifier));
        else
            return;
        event.accepted = true;
    }
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
