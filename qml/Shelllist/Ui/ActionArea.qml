import QtQuick

ActionControl {
    id: area

    required accessibleName
    property real focusRadius: Theme.controlRadius
    radius: focusRadius
    border.width: 0

    ControlPointerArea {
        focusTarget: area
        onClicked: area.activate()
    }
}
