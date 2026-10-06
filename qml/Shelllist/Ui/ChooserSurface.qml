import QtQuick

Rectangle {
    id: surface
    anchors.fill: parent
    radius: Theme.windowRadius
    color: Theme.shellColor
    border.width: 0

    // Keep the stroke off the native clip edge. Fractional-scale placement can
    // otherwise lose the final raster row/column, including the bottom border.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, surface.radius - 1)
        color: "transparent"
        border.color: Theme.strongBorder
        border.width: 1
        z: 1
        Accessible.ignored: true
    }
}
