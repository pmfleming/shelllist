import QtQuick

ActionControl {
    id: area

    required accessibleName
    property real focusRadius: Theme.controlRadius
    readonly property bool hovered: pointer.containsMouse
    radius: focusRadius
    border.width: activeFocus ? 1 : 0
    border.color: Theme.accent

    ControlPointerArea {
        id: pointer
        focusTarget: area
        onClicked: area.activate()
    }
}
