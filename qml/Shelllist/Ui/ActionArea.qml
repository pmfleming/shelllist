import QtQuick

ActionControl {
    id: area

    required accessibleName
    property real focusRadius: Theme.controlRadius
    radius: focusRadius
    border.width: activeFocus ? 1 : 0
    border.color: Theme.accent

    ControlPointerArea {
        focusTarget: area
        onClicked: area.activate()
    }
}
