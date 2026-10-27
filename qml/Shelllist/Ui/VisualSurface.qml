import QtQuick

Item {
    id: surface

    required property real contentWidth
    property real canvasWidth: contentWidth
    property bool horizontalOverflowAllowed: true
    property real minimumContentHeight: 0
    required property bool loadWhen
    required property Component content
    property bool retainLoaded: false
    property bool loadedOnce: false

    x: 0
    width: contentWidth
    height: parent ? parent.height : 0
    clip: true

    onLoadWhenChanged: if (loadWhen)
        loadedOnce = true
    Component.onCompleted: if (loadWhen)
        loadedOnce = true

    SurfaceViewport {
        id: viewport
        anchors.fill: parent
        canvasWidth: surface.canvasWidth
        horizontalOverflowAllowed: surface.horizontalOverflowAllowed
        canvasHeight: Math.max(height, surface.minimumContentHeight)

        Loader {
            width: viewport.contentWidth
            height: viewport.contentHeight
            active: surface.loadWhen || (surface.retainLoaded && surface.loadedOnce)
            sourceComponent: surface.content
        }
    }
}
