import QtQuick
import "."

Rectangle {
    id: field

    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property bool readOnly: false

    signal edited(string value)

    implicitHeight: 38
    radius: Theme.controlRadius
    color: Theme.input
    border.color: input.activeFocus ? Theme.strongBorder : Theme.border
    opacity: readOnly ? 0.72 : 1.0

    TextInput {
        id: input

        anchors.fill: parent
        leftPadding: 12
        rightPadding: 12
        readOnly: field.readOnly
        echoMode: field.password ? TextInput.Password : TextInput.Normal
        color: Theme.inputText
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: 13
        verticalAlignment: TextInput.AlignVCenter
        onTextEdited: field.edited(text)

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
