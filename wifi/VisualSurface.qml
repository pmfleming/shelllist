import QtQuick
import "."

Item {
    id: surface
    required property var controller; required property bool loadWhen; required property Component content
    x: Math.round((controller.surfaceWindowWidth - controller.currentWindowWidth) / 2)
    y: 0
    width: controller.currentWindowWidth
    height: parent ? parent.height : 0
    clip: true
    SurfaceLoader { loadWhen: surface.loadWhen; content: surface.content }
}
