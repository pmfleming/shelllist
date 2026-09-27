import QtQuick
import QtQuick.Effects

RectangularShadow {
    id: root

    property int level: 1
    property color shadowColor: Theme.dark ? "#b3000000" : "#52000000"
    readonly property real depth: [0, 1, 3, 6, 10][Math.max(0, Math.min(4, level))]

    visible: level > 0
    color: shadowColor
    blur: Math.max(1, Math.pow(depth * 5, 0.72))
    spread: -depth * 0.22
    offset.y: Math.max(1, depth * 0.55)

    InteractiveBehavior on blur {
        duration: Theme.animationNormal
        easingType: Theme.easingGentle
    }
    InteractiveBehavior on offset.y {
        duration: Theme.animationNormal
        easingType: Theme.easingGentle
    }
}
