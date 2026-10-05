import QtQuick

PointerActionControl {
    pointerEnabled: enabled

    required accessibleName
    property real focusRadius: Theme.controlRadius
    radius: focusRadius
    border.width: 0
}
