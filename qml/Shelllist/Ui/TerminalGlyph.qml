import QtQuick
import QtQuick.Shapes

// Passive, font-independent >_ artwork. The shared UI owner keeps this 24-unit
// geometry separate from control sizing; no terminal-window frame or tile.
Item {
    id: icon

    property color color: Theme.mutedText
    property bool bold: false

    implicitWidth: Theme.iconSize
    implicitHeight: Theme.iconSize
    Accessible.ignored: true

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: Math.min(icon.width, icon.height) / width
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: icon.color
            strokeWidth: icon.bold ? 2.4 : 2
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M2 5 L9 12 L2 19 M15 19 H22" }
        }
    }
}
