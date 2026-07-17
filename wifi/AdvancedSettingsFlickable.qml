import QtQuick

Flickable {
    anchors.fill: parent
    contentWidth: width
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    clip: true
}
