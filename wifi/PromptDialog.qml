import QtQuick
import "."

Rectangle {
    id: dialog

    property string title: ""
    property string detail: ""
    property string inputText: ""
    property bool password: false
    property bool saveVisible: false
    property bool saveRequested: false

    signal inputEdited(string text)
    signal accepted
    signal cancelled
    signal saveEdited(bool requested)

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
        height: dialog.saveVisible ? 304 : 270
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
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
                maximumLineCount: 5
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

            Rectangle {
                visible: dialog.saveVisible
                width: parent.width
                height: visible ? 32 : 0
                color: "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 4
                        color: dialog.saveRequested ? Theme.accent : Theme.input
                        border.color: dialog.saveRequested ? Theme.accent : Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: dialog.saveRequested ? "✓" : ""
                            color: Theme.accentText
                            font.bold: true
                        }
                    }

                    Text {
                        text: "Save in the desktop keyring"
                        color: Theme.text
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dialog.saveEdited(!dialog.saveRequested)
                }
            }

            Text {
                width: parent.width
                text: "Enter continue   •   Esc cancel"
                color: Theme.subtleText
                font.pixelSize: 13
            }
        }
    }
}
