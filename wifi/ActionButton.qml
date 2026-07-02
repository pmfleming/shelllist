import QtQuick
import "Wifi.js" as Wifi
import "."

Rectangle {
    id: control

    property string label: ""
    property string hotkey: ""
    property color backgroundColor: Theme.surfaceRaised
    property color borderColor: Theme.mix(Theme.border, Theme.text, 0.16)
    property color labelColor: Theme.text

    signal clicked

    height: 42
    radius: Theme.controlRadius
    color: enabled && area.containsMouse ? Theme.mix(backgroundColor, labelColor, 0.08) : backgroundColor
    border.color: borderColor
    border.width: 1
    opacity: enabled ? 1.0 : 0.45

    Text {
        anchors.centerIn: parent
        text: Wifi.highlightHotkey(control.label, control.hotkey)
        textFormat: Text.RichText
        color: control.labelColor
        font.pixelSize: 13
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: control.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.clicked()
    }
}
