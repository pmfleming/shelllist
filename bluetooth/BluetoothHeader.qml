import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

RowLayout {
    id: header

    required property real uiScale
    property string filterText: ""
    property bool powered: false
    property bool scanning: false
    property bool powerEnabled: true
    property bool scanEnabled: true

    signal filterEdited(string text)
    signal keyPressed(var event)
    signal powerRequested
    signal scanRequested

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

    Ui.ActionButton {
        Layout.preferredWidth: header.scaled(56)
        Layout.preferredHeight: header.scaled(Ui.Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        label: header.powered ? "ON" : "OFF"
        tone: header.powered ? "accent" : "normal"
        enabled: header.powerEnabled
        onClicked: header.powerRequested()
    }

    Ui.IconTile {
        Layout.preferredWidth: header.scaled(Ui.Theme.controlHeight)
        Layout.preferredHeight: header.scaled(Ui.Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        backgroundColor: Ui.Theme.controlBackground
        borderColor: Ui.Theme.border
        icon: "󰑐"
        iconColor: header.scanning ? Ui.Theme.accent : Ui.Theme.text
        iconSize: Math.max(Ui.Theme.iconSizeSmall, header.scaled(Ui.Theme.iconSize))
        clickable: true
        enabled: header.scanEnabled
        onClicked: header.scanRequested()

        NumberAnimation on iconRotation {
            running: header.scanning && !Ui.Theme.noAnimations
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: Ui.Theme.spinnerDuration
        }
    }
}
