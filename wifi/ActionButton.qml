import QtQuick
import "WifiPresentation.js" as Presentation
import Shelllist.Ui

Rectangle {
    id: control

    property string label: ""
    property string icon: ""
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

    Row {
        anchors.centerIn: parent
        spacing: 8

        Text {
            visible: control.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: control.icon
            color: control.labelColor
            font.family: Theme.iconFontFamily
            font.pixelSize: 15
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Presentation.highlightHotkey(control.label, control.hotkey)
            textFormat: Text.RichText
            color: control.labelColor
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
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
