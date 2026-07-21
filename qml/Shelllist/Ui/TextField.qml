import QtQuick

Rectangle {
    id: field

    property alias text: input.text
    property alias horizontalAlignment: input.horizontalAlignment
    property alias cursorPosition: input.cursorPosition
    property alias leftPadding: input.leftPadding
    property alias rightPadding: input.rightPadding
    readonly property alias inputActiveFocus: input.activeFocus
    property string placeholder: ""
    property bool password: false
    property bool readOnly: false
    property bool inputValid: true
    property int inputMethodHints: Qt.ImhNone
    property int maximumLength: 32767
    property int fontPixelSize: Theme.fontSizeBody

    signal edited(string value)
    signal editingFinished
    signal accepted
    signal keyPressed(var event)

    implicitHeight: Theme.compactControlHeight
    radius: Theme.controlRadius
    color: Theme.input
    border.color: !inputValid ? Theme.danger : (input.activeFocus ? Theme.strongBorder : Theme.border)
    opacity: enabled ? (readOnly ? Theme.readOnlyOpacity : 1.0) : Theme.disabledOpacity

    function focusInput(selectContents) {
        input.forceActiveFocus();
        if (selectContents)
            input.selectAll();
    }

    TextInput {
        id: input

        anchors.fill: parent
        leftPadding: Theme.spacingMd
        rightPadding: Theme.spacingMd
        readOnly: field.readOnly
        inputMethodHints: field.inputMethodHints
        maximumLength: field.maximumLength
        echoMode: field.password ? TextInput.Password : TextInput.Normal
        color: Theme.inputText
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: field.fontPixelSize
        verticalAlignment: TextInput.AlignVCenter
        onTextEdited: field.edited(text)
        onEditingFinished: field.editingFinished()
        onAccepted: field.accepted()
        Keys.onPressed: function (event) { field.keyPressed(event); }

        Text {
            anchors.fill: parent
            leftPadding: input.leftPadding
            rightPadding: input.rightPadding
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0
            text: field.placeholder
            color: Theme.subtleText
            font.family: Theme.fontFamily
            font.pixelSize: field.fontPixelSize
        }
    }
}
