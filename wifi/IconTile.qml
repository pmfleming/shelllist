import QtQuick
import Shelllist.Ui

Rectangle {
    id: tile

    property string icon: ""
    property color iconColor: Theme.text
    property color backgroundColor: "transparent"
    property color borderColor: "transparent"
    property int iconSize: 18
    property bool clickable: false

    signal clicked

    radius: Theme.controlRadius
    color: backgroundColor
    border.color: borderColor

    Text {
        anchors.centerIn: parent
        text: tile.icon
        color: tile.iconColor
        font.family: Theme.iconFontFamily
        font.pixelSize: tile.iconSize
    }

    MouseArea {
        anchors.fill: parent
        enabled: tile.clickable
        hoverEnabled: tile.clickable
        cursorShape: tile.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: tile.clicked()
    }
}
