import QtQuick
import "UiText.js" as UiText

Rectangle {
    id: tab

    property string label: ""
    property string icon: ""
    property string hotkey: ""
    property bool selected: false

    signal clicked

    color: selected ? Theme.selected
        : (enabled && area.pressed ? Theme.pressed
        : (enabled && area.containsMouse ? Theme.hover : "transparent"))
    border.color: activeFocus ? Theme.strongBorder : "transparent"
    border.width: 1
    opacity: enabled ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: enabled

    Keys.onReturnPressed: function (event) { tab.clicked(); event.accepted = true; }
    Keys.onEnterPressed: function (event) { tab.clicked(); event.accepted = true; }
    Keys.onSpacePressed: function (event) { tab.clicked(); event.accepted = true; }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingMd
        height: 3
        radius: 2
        color: Theme.accent
        visible: tab.selected
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingSm

        Text {
            visible: tab.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: tab.icon
            color: tab.selected ? Theme.accent : Theme.mutedText
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSizeSmall
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: UiText.highlightHotkey(tab.label, tab.hotkey)
            textFormat: Text.RichText
            color: tab.selected ? Theme.accent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            font.weight: tab.selected ? Theme.fontWeightDemiBold : Theme.fontWeightRegular
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: tab.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: tab.forceActiveFocus()
        onClicked: tab.clicked()
    }
}
