import QtQuick
import QtQuick.Layouts
import Shelllist.Ui

RowLayout {
    id: header

    required property real uiScale
    property string filterText: ""
    property bool refreshing: false
    property bool refreshEnabled: true

    signal filterEdited(string text)
    signal keyPressed(var event)
    signal refreshRequested

    Layout.fillWidth: true
    Layout.preferredHeight: Math.round(Theme.headerHeight * uiScale)
    spacing: Math.round(Theme.spacingSm * uiScale)

    function scaled(value) { return Math.round(value * uiScale); }

    Component.onCompleted: Qt.callLater(focusSearch)

    function focusSearch() {
        search.focusInput(false);
    }

    Item {
        Layout.preferredWidth: header.scaled(2)
    }

    Rectangle {
        Layout.preferredWidth: header.scaled(Theme.controlHeight)
        Layout.preferredHeight: header.scaled(Theme.controlHeight)
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

    TextField {
        id: search

        Layout.fillWidth: true
        Layout.preferredHeight: header.scaled(Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        leftPadding: header.scaled(43)
        rightPadding: header.scaled(Theme.spacingMd)
        fontPixelSize: Math.max(Theme.fontSizeSmall, header.scaled(Theme.fontSizeLabel))
        text: header.filterText
        placeholder: "Search networks…"
        onEdited: function (text) { header.filterEdited(text); }
        onKeyPressed: function (event) { header.keyPressed(event); }

        Text {
            x: header.scaled(Theme.contentMargin)
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: Theme.mutedText
            font.family: Theme.iconFontFamily
            font.pixelSize: Math.max(Theme.fontSizeLabel, header.scaled(Theme.iconSize))
        }
    }

    RefreshTile {
        Layout.preferredWidth: header.scaled(Theme.controlHeight)
        Layout.preferredHeight: header.scaled(Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        refreshing: header.refreshing
        refreshEnabled: header.refreshEnabled
        iconSize: Math.max(16, header.scaled(19))
        onClicked: header.refreshRequested()
    }
}
