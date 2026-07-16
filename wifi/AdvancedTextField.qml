import QtQuick
import "."

Rectangle {
    id: field

    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property bool readOnly: false
    property bool inputValid: true
    property int inputMethodHints: Qt.ImhNone
    property int maximumLength: 32767

    signal edited(string value)
    signal editingFinished

    implicitHeight: 38
    radius: Theme.controlRadius
    color: Theme.input
    border.color: !inputValid ? Theme.danger : (input.activeFocus ? Theme.strongBorder : Theme.border)
    opacity: readOnly ? 0.72 : 1.0

    TextInput {
        id: input

        anchors.fill: parent
        leftPadding: 12
        rightPadding: 12
        readOnly: field.readOnly
        inputMethodHints: field.inputMethodHints
        maximumLength: field.maximumLength
        echoMode: field.password ? TextInput.Password : TextInput.Normal
        color: Theme.inputText
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: 13
        verticalAlignment: TextInput.AlignVCenter
        onTextEdited: field.edited(text)
        onEditingFinished: field.editingFinished()

        Text {
            anchors.fill: parent
            leftPadding: 12
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0
            text: field.placeholder
            color: Theme.subtleText
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }
}
