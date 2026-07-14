import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: header

    property string filterText: ""

    signal filterEdited(string text)
    signal keyPressed(var event)
    signal refreshRequested

    Layout.fillWidth: true
    Layout.preferredHeight: 46
    spacing: 12

    function focusSearch() {
        search.forceActiveFocus();
    }

    IconTile {
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        Layout.alignment: Qt.AlignVCenter
        radius: Theme.cardRadius
        backgroundColor: Theme.selected
        icon: "󰤨"
        iconColor: Theme.accent
    }

    TextInput {
        id: search
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        Layout.alignment: Qt.AlignVCenter
        focus: true
        leftPadding: 38
        rightPadding: 12
        color: Theme.inputText
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.pixelSize: 15
        verticalAlignment: TextInput.AlignVCenter
        text: header.filterText
        onTextChanged: header.filterEdited(text)
        Keys.onPressed: function (event) {
            header.keyPressed(event);
        }

        Text {
            x: 12
            y: Math.round((parent.height - height) / 2)
            text: "⌕"
            color: Theme.subtleText
            font.pixelSize: 22
        }

        InputBackground {}
    }

    IconTile {
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        Layout.alignment: Qt.AlignVCenter
        borderColor: Theme.border
        icon: "↻"
        iconColor: Theme.mutedText
        iconSize: 20
        clickable: true
        onClicked: header.refreshRequested()
    }
}
