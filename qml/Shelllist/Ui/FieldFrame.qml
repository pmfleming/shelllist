import QtQuick

// Paint only: native editors retain transaction, selection and popup ownership.
Rectangle {
    id: frame

    property bool formStyle: true
    property bool outlined: false
    property bool focused: false
    property bool browseFocused: false
    readonly property bool highlighted: focused || browseFocused
    property bool invalid: false
    property bool hovered: false

    radius: formStyle ? Theme.formRadius : 4
    color: formStyle ? Theme.input : Theme.surface
    border.width: formStyle && !outlined ? 0 : 1
    border.color: invalid ? Theme.danger : (highlighted ? Theme.accent : (hovered ? Theme.text : Theme.controlBorder))

    Rectangle {
        anchors.fill: parent
        radius: frame.radius
        color: Theme.hover
        visible: frame.formStyle && frame.hovered && !frame.highlighted
    }
    Rectangle {
        objectName: "fieldBaseline"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.formRadius
        anchors.bottomMargin: 0
        height: frame.invalid ? 2 : 1
        color: frame.invalid ? Theme.danger : Theme.mutedText
        visible: frame.formStyle && !frame.outlined && !frame.focused
    }
    FocusRing {
        active: frame.highlighted
        editing: frame.focused
        cornerRadius: frame.radius
        ringColor: frame.invalid ? Theme.danger : Theme.accent
    }
}
