pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Required-input modal composition. Reads and domain submissions belong to its owner.
PromptDialog {
    id: dialog
    property string query: ""
    property var choices: []
    property string choice: ""
    property bool searching: false
    property string choiceLabel: qsTr("City")
    signal queryEdited(string query)
    signal choiceSelected(string value)

    inputVisible: false
    actionsVisible: true
    inlineHeaderActions: true
    actionSummaryVisible: false
    enterEnabled: false
    escapeEnabled: !search.popupVisible
    instruction: ""

    function focusInput(): void { search.focusInput(true); }

    FormField {
        Layout.fillWidth: true
        label: dialog.choiceLabel
        SearchChoiceField {
            id: search
            objectName: "searchChoiceQuery"
            Layout.fillWidth: true
            query: dialog.query
            options: dialog.choices
            value: dialog.choice
            searching: dialog.searching
            maximumLength: 120
            onQueryEdited: function(query) { dialog.queryEdited(query); }
            onSelected: function(value) { dialog.choiceSelected(value); }
        }
    }
}
