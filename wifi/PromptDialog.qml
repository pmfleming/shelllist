import QtQuick
import "."

Rectangle {
    id: dialog

    property string title: ""
    property string detail: ""
    property string inputText: ""
    property bool password: false

    signal inputEdited(string text)
    signal accepted
    signal cancelled

    anchors.fill: parent
    z: 10
    color: Theme.overlay

    function focusInput() {
        promptInput.forceActiveFocus();
        promptInput.selectAll();
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(focusInput);
    }

    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        width: Math.min(parent.width * 0.9, 560)
        height: 230
        anchors.centerIn: parent
        radius: Theme.windowRadius
        color: Theme.surface
        border.color: Theme.strongBorder
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                width: parent.width
                text: dialog.title
                color: Theme.text
                font.pixelSize: 22
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: dialog.detail
                color: Theme.mutedText
                font.pixelSize: 14
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            TextInput {
                id: promptInput
                width: parent.width
                height: 44
                color: Theme.inputText
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                font.pixelSize: 19
                text: dialog.inputText
                echoMode: dialog.password ? TextInput.Password : TextInput.Normal
                onTextChanged: dialog.inputEdited(text)
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        dialog.accepted();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        dialog.cancelled();
                        event.accepted = true;
                    }
                }

                InputBackground {}
            }

            Text {
                width: parent.width
                text: "Enter continue/connect   •   Esc cancel"
                color: Theme.subtleText
                font.pixelSize: 13
            }
        }
    }
}
