import QtQuick

// Immediate, input-transparent focus: subtle browse tone, stronger edit tone
// and accent edge. The parent is always the editable surface, never its label.
Rectangle {
    property bool active: false
    property bool editing: false
    property real cornerRadius: Theme.controlRadius
    property color ringColor: Theme.accent

    objectName: "focusRing"
    anchors.fill: parent
    anchors.margins: Theme.focusRingInset
    radius: Math.max(0, cornerRadius - Theme.focusRingInset)
    color: Theme.withAlpha(ringColor, editing ? 0.22 : 0.08)
    border.width: editing ? 2 : 0
    border.color: ringColor
    visible: active
    z: 100
    Accessible.ignored: true
}
