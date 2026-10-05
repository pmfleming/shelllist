import QtQuick

PointerActionControl {
    id: control

    property bool checked: false
    property color checkedColor: Theme.accent
    property color uncheckedColor: Theme.input

    signal toggled(bool checked)

    implicitWidth: 64
    implicitHeight: Theme.controlHeight
    radius: Math.min(width, height) / 2
    color: pointerPressed ? Theme.pressed : (hovered || highlighted ? Theme.hover : "transparent")
    border.width: 0
    opacity: enabled && interactive ? 1.0 : Theme.disabledOpacity
    accessibleName: checked ? qsTr("Turn off") : qsTr("Turn on")
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    Accessible.onToggleAction: activate()
    onClicked: toggled(!checked)

    TogglePill {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, control.width)
        height: Math.min(implicitHeight, control.height, width * 32 / 52)
        checked: control.checked
        pressed: control.pressed
        checkedColor: control.checkedColor
        uncheckedColor: control.uncheckedColor
    }
}
