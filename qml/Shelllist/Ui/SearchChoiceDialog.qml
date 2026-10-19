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
    property string queryLabel: qsTr("City search")
    property string choiceLabel: qsTr("City")
    signal queryEdited(string query)
    signal choiceSelected(string value)

    inputVisible: false
    actionsVisible: true
    enterEnabled: false
    instruction: ""

    function focusInput(): void { search.focusInput(false); }

    ColumnLayout {
        width: parent.width
        spacing: dialog.bodySpacing
        FormField {
            Layout.fillWidth: true
            label: dialog.queryLabel
            TextField {
                id: search
                objectName: "searchChoiceQuery"
                Layout.fillWidth: true
                text: dialog.query
                maximumLength: 120
                onEdited: function(text) { dialog.queryEdited(text); }
            }
        }
        FormField {
            Layout.fillWidth: true
            label: dialog.choiceLabel
            DropDownList {
                objectName: "searchChoiceCandidate"
                Layout.fillWidth: true
                options: dialog.choices
                value: dialog.choice
                placeholder: dialog.searching ? qsTr("Searching…") : qsTr("Select a city")
                onSelected: function(value) { dialog.choiceSelected(value); }
            }
        }
    }
}
