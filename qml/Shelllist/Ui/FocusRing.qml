import QtQuick

// Immediate, input-transparent focus. A small opaque marker qualifies the browse
// tint without outlining the control. Editing retains its stronger tone/edge.
// The parent is always the editable surface, never its label.
Rectangle {
    id: feedback
    property bool active: false
    property bool editing: false
    property bool browseIndicatorVisible: true
    property real cornerRadius: Theme.controlRadius
    property color ringColor: Theme.accent
    // Horizontal sliders keep the marker above, rather than over, their track.
    property bool horizontalIndicator: false

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

    Rectangle {
        objectName: "browseFocusIndicator"
        visible: feedback.browseIndicatorVisible && !feedback.editing
        x: feedback.horizontalIndicator ? (parent.width - width) / 2 : 1
        y: feedback.horizontalIndicator ? 1 : (parent.height - height) / 2
        width: Math.min(feedback.horizontalIndicator ? 14 : 5, Math.max(0, parent.width - 2))
        height: Math.min(feedback.horizontalIndicator ? 5 : 14, Math.max(0, parent.height - 2))
        radius: Math.min(width, height) / 2
        // The opaque surface keyline keeps Primary distinguishable even when
        // this decoration overlaps a filled switch, icon or slider handle.
        color: Theme.accent
        border.color: Theme.window
        border.width: 1
        Accessible.ignored: true
    }
}
