import QtQuick
import "Wifi.js" as Wifi
import "."

Rectangle {
    id: tab

    property string label: ""
    property string icon: ""
    property string hotkey: ""
    property bool selected: false

    signal clicked

    color: selected ? Theme.selected : (enabled && area.containsMouse ? Theme.hover : "transparent")
    opacity: enabled ? 1.0 : 0.45

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 3
        radius: 2
        color: Theme.accent
        visible: tab.selected
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Text {
            visible: tab.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: tab.icon
            color: tab.selected ? Theme.accent : Theme.mutedText
            font.family: Theme.iconFontFamily
            font.pixelSize: 15
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Wifi.highlightHotkey(tab.label, tab.hotkey)
            textFormat: Text.RichText
            color: tab.selected ? Theme.accent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: tab.selected ? Font.DemiBold : Font.Normal
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: tab.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tab.clicked()
    }
}
