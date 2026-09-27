import QtQuick

Rectangle {
    id: pill
    objectName: "toggleTrack"

    property bool checked: false
    property bool pressed: false
    property color checkedColor: Theme.accent
    property color uncheckedColor: Theme.input
    property color handleColor: checked ? Theme.accentText : Theme.controlBorder

    implicitWidth: 52
    implicitHeight: 32
    radius: height / 2
    color: checked ? checkedColor : uncheckedColor
    border.width: checked ? 0 : 2
    border.color: Theme.controlBorder

    ExpressiveMotion {
        id: position
        target: pill.checked ? 1 : 0
    }
    ExpressiveMotion {
        id: size
        target: pill.height * (pill.pressed ? 28 / 32 : (pill.checked ? 24 / 32 : 16 / 32))
    }

    Rectangle {
        objectName: "toggleHandle"
        width: Math.max(0, Math.min(pill.height, size.value))
        height: width
        radius: width / 2
        // Animate decoration, not checked state. A rapid reversal retargets the
        // existing spring; containment also holds for externally sized tracks.
        x: pill.height / 2 + Math.max(0, Math.min(1, position.value)) * (pill.width - pill.height) - width / 2
        y: (pill.height - height) / 2
        color: pill.handleColor
    }
}
