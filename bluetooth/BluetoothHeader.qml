import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

RowLayout {
    id: header

    required property real uiScale
    property string filterText: ""
    property bool powered: false
    property bool refreshing: false
    property bool powerEnabled: true
    property bool refreshEnabled: true

    signal filterEdited(string text)
    signal keyPressed(var event)
    signal powerRequested
    signal refreshRequested

    Layout.fillWidth: true
    Layout.preferredHeight: scaled(Ui.Theme.headerHeight)
    spacing: scaled(Ui.Theme.spacingSm)

    function scaled(value) { return Math.round(value * uiScale); }
    function focusSearch() { search.focusInput(false); }

    Item { Layout.preferredWidth: header.scaled(2) }

    Ui.IconTile {
        Layout.preferredWidth: header.scaled(Ui.Theme.controlHeight)
        Layout.preferredHeight: header.scaled(Ui.Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        backgroundColor: Ui.Theme.selected
        borderColor: Ui.Theme.mix(Ui.Theme.strongBorder, Ui.Theme.surface, 0.40)
        icon: "󰂯"
        iconColor: header.powered ? Ui.Theme.accent : Ui.Theme.mutedText
        iconSize: Math.max(Ui.Theme.iconSize, header.scaled(Ui.Theme.iconSizeLarge))
    }

    Ui.TextField {
        id: search

        Layout.fillWidth: true
        Layout.preferredHeight: header.scaled(Ui.Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        leftPadding: header.scaled(43)
        rightPadding: header.scaled(Ui.Theme.spacingMd)
        fontPixelSize: Math.max(Ui.Theme.fontSizeSmall, header.scaled(Ui.Theme.fontSizeLabel))
        text: header.filterText
        placeholder: "Search devices…"
        onEdited: function (text) { header.filterEdited(text); }
        onKeyPressed: function (event) { header.keyPressed(event); }

        Text {
            x: header.scaled(Ui.Theme.contentMargin)
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.iconFontFamily
            font.pixelSize: Math.max(Ui.Theme.fontSizeLabel, header.scaled(Ui.Theme.iconSize))
        }
    }

    Ui.ToggleSwitch {
        Layout.preferredWidth: header.scaled(56)
        Layout.preferredHeight: header.scaled(Ui.Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        checked: header.powered
        enabled: header.powerEnabled
        onToggled: header.powerRequested()
    }

    Ui.RefreshTile {
        Layout.preferredWidth: header.scaled(Ui.Theme.controlHeight)
        Layout.preferredHeight: header.scaled(Ui.Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        refreshing: header.refreshing
        refreshEnabled: header.refreshEnabled
        iconSize: Math.max(Ui.Theme.iconSizeSmall, header.scaled(Ui.Theme.iconSize))
        onClicked: header.refreshRequested()
    }
}
