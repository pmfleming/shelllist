import QtQuick
import Shelllist.Ui as Ui

Ui.TextEditor {
    id: field
    property string family: "ipv4"
    property bool allowEmpty: true
    property alias validationAttempted: validation.attempted
    readonly property int validationState: validation.state
    errorText: validation.errorText
    supportingText: qsTr("Comma or whitespace separated")
    font.family: Ui.Theme.iconFontFamily
    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
    onEditFinished: function (saved) {
        if (saved)
            validation.attempted = true;
    }
    onReadOnlyChanged: if (readOnly)
        validation.attempted = false
    FieldValidation {
        id: validation
        text: field.text
        family: field.family
        allowEmpty: field.allowEmpty
        multiple: true
    }
}
