import QtQuick

// Native multiline editing. A lease-owning domain can allow focus before its
// editor becomes writable; no draft/value is owned by presentation memory.
TextEdit {
    id: editor
    property bool browseFocused: false
    property bool editingAllowed: !readOnly
    FocusRing { active: editor.activeFocus || editor.browseFocused }
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
