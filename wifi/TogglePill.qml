import QtQuick

Rectangle {
    id: pill

    property bool checked: false
    property color checkedColor: "#3b82f6"
    property color uncheckedColor: "#334155"
    property color handleColor: "#dbeafe"

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
