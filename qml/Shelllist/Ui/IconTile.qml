import QtQuick

Rectangle {
    id: tile

    property string icon: ""
    property url iconSource: ""
    readonly property bool hasImage: artwork.status === Image.Ready
    property color iconColor: Theme.text
    property color backgroundColor: "transparent"
    property color borderColor: "transparent"
    property int iconSize: Theme.iconSize
    property real iconRotation: 0
    property bool clickable: false
    property bool browseFocused: false
    readonly property bool highlighted: activeFocus || browseFocused

    signal clicked

    implicitWidth: Theme.controlHeight
    implicitHeight: Theme.controlHeight
    radius: Theme.controlRadius
    color: !clickable ? backgroundColor : (area.pressed ? Theme.mix(backgroundColor, iconColor, 0.14) : (area.containsMouse || highlighted ? Theme.mix(backgroundColor, iconColor, 0.08) : backgroundColor))
    border.color: borderColor
    opacity: enabled ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: clickable && enabled

    Keys.onReturnPressed: function (event) {
        tile.clicked();
        event.accepted = true;
    }
    Keys.onEnterPressed: function (event) {
        tile.clicked();
        event.accepted = true;
    }
    Keys.onSpacePressed: function (event) {
        tile.clicked();
        event.accepted = true;
    }

    FocusRing {
        active: tile.highlighted && tile.clickable
        cornerRadius: tile.radius
        ringColor: tile.iconColor
    }

    Image {
        id: artwork
        anchors.centerIn: parent
        width: tile.iconSize
        height: tile.iconSize
        sourceSize.width: width
        sourceSize.height: height
        source: tile.iconSource
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        visible: tile.hasImage
    }
    GlyphLabel {
        visible: !tile.hasImage
        anchors.centerIn: parent
        glyph: tile.icon
        color: tile.iconColor
        font.pixelSize: tile.iconSize
        rotation: tile.iconRotation
    }

    StateLayer {
        id: area
        focusTarget: tile
        radius: tile.radius
        stateColor: tile.iconColor
        showStateBackground: false
        interactive: tile.clickable
        onClicked: tile.clicked()
    }
}
