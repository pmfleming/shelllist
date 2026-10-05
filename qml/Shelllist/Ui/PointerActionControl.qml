import QtQuick

// Standard single-click activation. Multi-button/wheel surfaces keep their own
// pointer adapter on ActionControl instead of layering two event receivers.
ActionControl {
    id: control
    property bool pointerEnabled: enabled && interactive
    readonly property bool hovered: pointer.containsMouse
    readonly property bool pointerPressed: pointer.pressed
    readonly property bool pressed: enabled && interactive && (pointerPressed || keyboardPressed)

    ControlPointerArea {
        id: pointer
        focusTarget: control
        enabled: control.pointerEnabled
        onClicked: control.activate()
    }
}
