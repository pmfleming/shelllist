import QtQuick

Item {
    id: surface

    required property real surfaceWidth
    required property real contentWidth
    required property bool loadWhen
    required property Component content
    property bool retainLoaded: false
    property bool loadedOnce: false

    x: Math.round((surfaceWidth - contentWidth) / 2)
    width: contentWidth
    height: parent ? parent.height : 0
    clip: true

    onLoadWhenChanged: if (loadWhen) loadedOnce = true
    Component.onCompleted: if (loadWhen) loadedOnce = true

    Loader {
        anchors.fill: parent
        active: surface.loadWhen || (surface.retainLoaded && surface.loadedOnce)
        sourceComponent: surface.content
    }
}
