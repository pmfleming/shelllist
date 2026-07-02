import QtQuick
import "."

Rectangle {
    id: tile
    property string icon: ""; property color iconColor: Theme.text; property color backgroundColor: "transparent"; property color borderColor: "transparent"
    property int iconSize: 18; property bool clickable: false
    signal clicked
    radius: Theme.controlRadius; color: backgroundColor; border.color: borderColor
    Text { anchors.centerIn: parent; text: tile.icon; color: tile.iconColor; font.pixelSize: tile.iconSize }
    MouseArea { anchors.fill: parent; enabled: tile.clickable; cursorShape: Qt.PointingHandCursor; onClicked: tile.clicked() }
}
