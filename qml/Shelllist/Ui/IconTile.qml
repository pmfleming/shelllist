import QtQuick

Rectangle {
    id: tile

    property string icon: ""
    property color iconColor: Theme.text
    property color backgroundColor: "transparent"
    property color borderColor: "transparent"
    property int iconSize: Theme.iconSize
    property real iconRotation: 0
    property bool clickable: false

    signal clicked

    implicitWidth: Theme.controlHeight
    implicitHeight: Theme.controlHeight
    radius: Theme.controlRadius
    color: !clickable ? backgroundColor
        : (area.pressed ? Theme.mix(backgroundColor, iconColor, 0.14)
        : (area.containsMouse ? Theme.mix(backgroundColor, iconColor, 0.08) : backgroundColor))
    border.color: activeFocus ? Theme.strongBorder : borderColor
    opacity: enabled ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: clickable && enabled

    Keys.onReturnPressed: function (event) { tile.clicked(); event.accepted = true; }
    Keys.onEnterPressed: function (event) { tile.clicked(); event.accepted = true; }
    Keys.onSpacePressed: function (event) { tile.clicked(); event.accepted = true; }

    Text {
        anchors.centerIn: parent
        text: tile.icon
        color: tile.iconColor
        font.family: Theme.iconFontFamily
        font.pixelSize: tile.iconSize
        rotation: tile.iconRotation
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: tile.clickable && tile.enabled
        hoverEnabled: tile.clickable
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: tile.forceActiveFocus()
        onClicked: tile.clicked()
    }
}
