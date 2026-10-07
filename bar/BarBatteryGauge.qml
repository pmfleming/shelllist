import QtQuick
import QtQuick.Shapes
import Shelllist.Ui as Ui
import "BarStatusPresentation.js" as Presentation

// Passive contents of one Battery action. State glyphs have a reserved slot
// beside the body; neither a glyph nor its gap is a separate input target.
Item {
    id: gauge
    objectName: "barBatteryGauge"
    required property var battery
    property color foreground: Ui.Theme.text
    readonly property bool known: Presentation.batteryKnown(battery)
    readonly property real fraction: Presentation.batteryFraction(battery)
    readonly property string stateMark: Presentation.batteryStateMark(battery)
    readonly property bool warning: !!battery && (!!battery.warning || !!battery.critical)
    implicitWidth: 38
    implicitHeight: 30
    Accessible.ignored: true

    Item {
        id: body
        objectName: "barBatteryBody"
        width: 20
        height: 30
        Rectangle {
            x: 7; y: 1
            width: 6; height: 3
            radius: 1
            color: gauge.foreground
        }
        Shape {
            anchors.fill: parent
            ShapePath {
                fillColor: "transparent"
                strokeColor: gauge.foreground
                strokeWidth: 1.5
                strokeStyle: gauge.known ? ShapePath.SolidLine : ShapePath.DashLine
                dashPattern: [2, 2]
                PathSvg { path: "M5 5 H15 Q18 5 18 8 V25 Q18 28 15 28 H5 Q2 28 2 25 V8 Q2 5 5 5 Z" }
            }
        }
        Rectangle {
            id: interior
            objectName: "barBatteryInterior"
            x: 5; y: 8
            width: 10; height: 17
            radius: 1
            color: Ui.Theme.withAlpha(gauge.foreground, 0.12)
            clip: true
            Rectangle {
                objectName: "barBatteryFill"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: gauge.fraction * interior.height
                radius: Math.min(1, height / 2)
                visible: gauge.known
                color: gauge.warning ? gauge.foreground : Ui.Theme.accent
                Ui.InteractiveBehavior on height {
                    animate: gauge.known && gauge.visible
                    duration: 160
                    easingType: Easing.OutCubic
                }
            }
        }
    }
    Ui.GlyphLabel {
        objectName: "barBatteryStateMark"
        x: body.width + 4
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 20
        clip: true
        glyph: gauge.stateMark
        color: gauge.foreground
        font.pixelSize: 14
        visible: gauge.stateMark.length > 0
        Accessible.ignored: true
    }
}
