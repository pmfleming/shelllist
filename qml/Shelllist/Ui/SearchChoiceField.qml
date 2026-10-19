pragma ComponentBehavior: Bound

import QtQuick

// A single native editor for required-input modals. Queries and chosen candidates
// are modal drafts; only the modal owner can submit a domain mutation.
TextField {
    id: control
    property string query: ""
    property var options: []
    property string value: ""
    property bool searching: false
    property bool expanded: false
    property int highlightedIndex: -1
    readonly property bool interactive: enabled && !readOnly
    readonly property int acknowledgedIndex: options.findIndex(option => String(option.value) === value)
    readonly property alias popup: suggestions
    readonly property bool popupVisible: suggestions.visible
    signal queryEdited(string query)
    signal selected(string value)

    text: acknowledgedIndex >= 0 ? optionText(options[acknowledgedIndex]) : query
    placeholder: searching ? qsTr("Searching…") : qsTr("Search or choose…")
    trailingActionIcon: expanded ? "expand_less" : "expand_more"
    trailingActionToolTip: qsTr("Show choices")
    trailingActionEnabled: interactive && options.length > 0
    trailingAction.activeFocusOnTab: false
    onTrailingActionRequested: {
        focusInput(false);
        expanded = !expanded;
        highlightedIndex = -1;
    }
    onEdited: function(text) {
        highlightedIndex = -1;
        queryEdited(text);
        expanded = true;
    }
    onOptionsChanged: highlightedIndex = -1
    onInputActiveFocusChanged: if (!inputActiveFocus) expanded = false
    onVisibleChanged: if (!visible) expanded = false

    function optionEnabled(index: int): bool {
        return index >= 0 && index < options.length && options[index].enabled !== false;
    }
    function optionText(option: var): string { return String(option.label || option.value || ""); }
    function acceptOptionClick(index: int): void {
        if (!interactive || !optionEnabled(index)) return;
        const choice = String(options[index].value);
        expanded = false;
        highlightedIndex = -1;
        selected(choice);
        focusInput(true);
    }
    function moveChoice(step: int): void {
        const start = expanded ? highlightedIndex : -1;
        expanded = true;
        for (let i = start + step; i >= 0 && i < options.length; i += step) {
            if (optionEnabled(i)) { highlightedIndex = i; return; }
        }
    }
    onKeyPressed: function(event) {
        if (inputMethodComposing || event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return;
        if (event.key === Qt.Key_Down) {
            moveChoice(1);
        } else if (event.key === Qt.Key_Up && expanded) {
            moveChoice(-1);
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && popupVisible) {
            acceptOptionClick(highlightedIndex);
        } else if (event.key === Qt.Key_Escape && expanded) {
            expanded = false;
        } else {
            return; // Left/Right, Home/End, selection and typing stay native.
        }
        event.accepted = true;
    }

    ChoicePopup {
        id: suggestions
        objectName: "searchChoicePopup"
        owner: control
        optionCount: control.options.length
        visible: control.expanded && control.inputActiveFocus && control.options.length > 0
        focus: false
        model: visible ? control.options : []
        currentIndex: control.highlightedIndex
        // Empty in-flight results must not forget the user's intent to browse.
        onClosed: if (control.options.length > 0) control.expanded = false
        delegate: DropDownOptionDelegate {
            owner: control
            focusPolicy: Qt.NoFocus
        }
    }
}
