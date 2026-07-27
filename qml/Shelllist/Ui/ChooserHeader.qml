import QtQuick
import QtQuick.Layouts

RowLayout {
    id: header

    required property real uiScale
    property string filterText: ""
    property string placeholder: "Search…"
    property string icon: ""
    property bool signalIcon: false
    property bool powered: false
    property bool refreshing: false
    property bool powerEnabled: true
    property bool refreshEnabled: true
    property string refreshIcon: "󰑐"
    property bool focusOnCompleted: false
    property bool iconActionEnabled: false

    signal filterEdited(string text)
    signal keyPressed(var event)
    signal iconClicked
    signal powerRequested
    signal refreshRequested

    Layout.fillWidth: true
    Layout.preferredHeight: scaled(Theme.headerHeight)
    spacing: scaled(Theme.spacingSm)

    function scaled(value) {
        return Math.round(value * uiScale);
    }
    function focusSearch() {
        search.focusInput(false);
    }

    Component.onCompleted: if (focusOnCompleted)
        Qt.callLater(focusSearch)

    Item {
        Layout.preferredWidth: header.scaled(2)
    }

    IconTile {
        Layout.preferredWidth: header.scaled(Theme.controlHeight)
        Layout.preferredHeight: header.scaled(Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        backgroundColor: Theme.selected
        borderColor: Theme.mix(Theme.strongBorder, Theme.surface, 0.40)
        icon: header.signalIcon ? "" : header.icon
        iconColor: header.powered ? Theme.accent : Theme.mutedText
        iconSize: Math.max(Theme.iconSize, header.scaled(Theme.iconSizeLarge))
        clickable: header.iconActionEnabled
        onClicked: header.iconClicked()

        SignalIcon {
            visible: header.signalIcon
            anchors.centerIn: parent
            width: header.scaled(25)
            height: header.scaled(22)
            level: 3
            iconColor: header.powered ? Theme.accent : Theme.mutedText
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
        placeholder: header.placeholder
        onEdited: function (text) {
            header.filterEdited(text);
        }
        onKeyPressed: function (event) {
            header.keyPressed(event);
        }

        Text {
            x: header.scaled(Theme.contentMargin)
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: Theme.mutedText
            font.family: Theme.iconFontFamily
            font.pixelSize: Math.max(Theme.fontSizeLabel, header.scaled(Theme.iconSize))
        }
    }

    ToggleSwitch {
        Layout.preferredWidth: header.scaled(56)
        Layout.preferredHeight: header.scaled(Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        checked: header.powered
        enabled: header.powerEnabled
        onToggled: header.powerRequested()
    }

    RefreshTile {
        Layout.preferredWidth: header.scaled(Theme.controlHeight)
        Layout.preferredHeight: header.scaled(Theme.controlHeight)
        Layout.alignment: Qt.AlignVCenter
        refreshing: header.refreshing
        refreshEnabled: header.refreshEnabled
        icon: header.refreshIcon
        iconSize: Math.max(Theme.iconSizeSmall, header.scaled(Theme.iconSize))
        onClicked: header.refreshRequested()
    }
}
