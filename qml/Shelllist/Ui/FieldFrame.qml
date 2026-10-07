import QtQuick

// Paint only: native editors retain transaction, selection and popup ownership.
Rectangle {
    id: frame

    property bool formStyle: true
    property bool outlined: false
    property bool rowEmbedded: false
    property bool readOnly: false
    property bool focused: false
    property bool browseFocused: false
    readonly property bool highlighted: focused || browseFocused
    property bool invalid: false
    property bool hovered: false

    radius: formStyle ? Theme.formRadius : 4
    color: formStyle ? "transparent" : Theme.surface
    border.width: formStyle && !outlined ? 0 : 1
    border.color: invalid ? Theme.danger : (highlighted ? Theme.accent : (hovered ? Theme.text : Theme.controlBorder))

    Rectangle {
        anchors.fill: parent
        radius: frame.radius
        color: Theme.hover
        visible: frame.formStyle && frame.enabled && !frame.readOnly && frame.hovered && !frame.highlighted
    }
    Rectangle {
        objectName: "fieldBaseline"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.formPadding
        anchors.bottomMargin: 0
        height: frame.invalid ? 2 : 1
        color: frame.invalid ? Theme.danger : Theme.border
        visible: frame.formStyle && !frame.outlined && !frame.focused && (!frame.rowEmbedded || frame.invalid)
    }
    FocusRing {
        active: frame.highlighted && frame.enabled && !frame.readOnly
        editing: frame.focused
        cornerRadius: frame.radius
        ringColor: frame.invalid ? Theme.danger : Theme.accent
    }
}
