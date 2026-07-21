import QtQuick

Rectangle {
    id: pill

    property bool checked: false
    property color checkedColor: Theme.accent
    property color uncheckedColor: Theme.border
    property color handleColor: Theme.accentText

    implicitWidth: 42
    implicitHeight: 24
    radius: height / 2
    color: checked ? checkedColor : uncheckedColor

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        x: pill.checked ? pill.width - width - 3 : 3
        y: 3
        color: pill.handleColor

        Behavior on x {
            enabled: !Theme.noAnimations
            NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingStandard }
        }
    }
}
