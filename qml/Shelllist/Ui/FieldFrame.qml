import QtQuick

// Shared outlined field paint. Native inputs retain editing and popup ownership.
Rectangle {
    id: frame

    property bool focused: false
    property bool invalid: false
    property bool hovered: false

    radius: 4
    color: Theme.surface
    border.width: focused ? 0 : 1
    border.color: invalid ? Theme.danger : (hovered ? Theme.text : Theme.controlBorder)

    // Keep the same immediate, inset keyboard indicator as other controls.
    FocusRing {
        active: frame.focused
        cornerRadius: frame.radius
        ringColor: frame.invalid ? Theme.danger : Theme.accent
    }
}
