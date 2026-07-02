import QtQuick
import "."

Rectangle {
    id: pill

    property bool checked: false
    property color checkedColor: Theme.accent
    property color uncheckedColor: Theme.border
    property color handleColor: Theme.accentText

    width: 34
    height: 20
    radius: height / 2
    color: checked ? checkedColor : uncheckedColor

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        x: pill.checked ? pill.width - width - 3 : 3
        y: 3
        color: pill.handleColor
    }
}
