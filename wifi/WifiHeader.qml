import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui

RowLayout {
    id: header

    property string filterText: ""

    signal filterEdited(string text)
    signal keyPressed(var event)
    signal refreshRequested

    Layout.fillWidth: true
    Layout.preferredHeight: 48
    spacing: 10

    function focusSearch() {
        search.forceActiveFocus();
    }

    Item {
        Layout.preferredWidth: 2
    }

    Rectangle {
        Layout.preferredWidth: 42
        Layout.preferredHeight: 42
        Layout.alignment: Qt.AlignVCenter
        radius: Theme.cardRadius
        color: Theme.selected
        border.color: Theme.mix(Theme.strongBorder, Theme.surface, 0.40)

        SignalIcon {
            anchors.centerIn: parent
            width: 25
            height: 22
            level: 3
            iconColor: Theme.accent
        }
    }

    TextInput {
        id: search

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        Layout.alignment: Qt.AlignVCenter
        focus: true
        leftPadding: 43
        rightPadding: 12
        color: Theme.inputText
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: 14
        verticalAlignment: TextInput.AlignVCenter
        text: header.filterText
        onTextChanged: header.filterEdited(text)
        Keys.onPressed: function (event) {
            header.keyPressed(event);
        }

        Text {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: Theme.mutedText
            font.family: Theme.iconFontFamily
            font.pixelSize: 17
        }

        Text {
            x: 43
            anchors.verticalCenter: parent.verticalCenter
            visible: search.text.length === 0
            text: "Search networks…"
            color: Theme.subtleText
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }

        InputBackground {}
    }

    IconTile {
        Layout.preferredWidth: 42
        Layout.preferredHeight: 42
        Layout.alignment: Qt.AlignVCenter
        backgroundColor: Theme.surfaceRaised
        borderColor: Theme.border
        icon: "󰑐"
        iconColor: Theme.text
        iconSize: 19
        clickable: true
        onClicked: header.refreshRequested()
    }
}
