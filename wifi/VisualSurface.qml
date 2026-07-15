import QtQuick

Item {
    id: surface

    required property real surfaceWidth
    required property real contentWidth
    required property bool loadWhen
    required property Component content

    x: Math.round((surfaceWidth - contentWidth) / 2)
    width: contentWidth
    height: parent ? parent.height : 0
    clip: true

    Loader {
        anchors.fill: parent
        active: surface.loadWhen
        sourceComponent: surface.content
    }
}
