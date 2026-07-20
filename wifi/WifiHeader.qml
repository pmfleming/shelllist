import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui

RowLayout {
    id: header

    required property real uiScale
    property string filterText: ""

    signal filterEdited(string text)
    signal keyPressed(var event)
    signal refreshRequested

    Layout.fillWidth: true
    Layout.preferredHeight: Math.round(48 * uiScale)
    spacing: Math.round(10 * uiScale)

    function scaled(value) { return Math.round(value * uiScale); }

    function focusSearch() {
        search.forceActiveFocus();
    }

    Item {
        Layout.preferredWidth: header.scaled(2)
    }

    Rectangle {
        Layout.preferredWidth: header.scaled(42)
        Layout.preferredHeight: header.scaled(42)
        Layout.alignment: Qt.AlignVCenter
        radius: Theme.cardRadius
        color: Theme.selected
        border.color: Theme.mix(Theme.strongBorder, Theme.surface, 0.40)

        SignalIcon {
            anchors.centerIn: parent
            width: header.scaled(25)
            height: header.scaled(22)
            level: 3
            iconColor: Theme.accent
        }
    }

    TextInput {
        id: search

        Layout.fillWidth: true
        Layout.preferredHeight: header.scaled(42)
        Layout.alignment: Qt.AlignVCenter
        focus: true
        leftPadding: header.scaled(43)
        rightPadding: header.scaled(12)
        color: Theme.inputText
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(12, header.scaled(14))
        verticalAlignment: TextInput.AlignVCenter
        text: header.filterText
        onTextChanged: header.filterEdited(text)
        Keys.onPressed: function (event) {
            header.keyPressed(event);
        }

        Text {
            x: header.scaled(14)
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: Theme.mutedText
            font.family: Theme.iconFontFamily
            font.pixelSize: Math.max(14, header.scaled(17))
        }

        Text {
            x: header.scaled(43)
            anchors.verticalCenter: parent.verticalCenter
            visible: search.text.length === 0
            text: "Search networks…"
            color: Theme.subtleText
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(12, header.scaled(14))
        }

        InputBackground {}
    }

    IconTile {
        Layout.preferredWidth: header.scaled(42)
        Layout.preferredHeight: header.scaled(42)
        Layout.alignment: Qt.AlignVCenter
        backgroundColor: Theme.surfaceRaised
        borderColor: Theme.border
        icon: "󰑐"
        iconColor: Theme.text
        iconSize: Math.max(16, header.scaled(19))
        clickable: true
        onClicked: header.refreshRequested()
    }
}
