import QtQuick

// Shared outlined field paint. Native inputs retain editing and popup ownership.
Rectangle {
    id: frame

    property bool focused: false
    property bool browseFocused: false
    readonly property bool highlighted: focused || browseFocused
    property bool invalid: false
    property bool hovered: false

    radius: 4
    color: Theme.surface
    border.width: 1
    border.color: invalid ? Theme.danger : (highlighted ? Theme.accent : (hovered ? Theme.text : Theme.controlBorder))

    // One native field boundary plus the shared tonal focus state.
    FocusRing {
        active: frame.highlighted
        editing: frame.focused
        cornerRadius: frame.radius
        ringColor: frame.invalid ? Theme.danger : Theme.accent
    }
}
