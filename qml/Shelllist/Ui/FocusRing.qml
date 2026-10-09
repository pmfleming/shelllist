import QtQuick

// Immediate, input-transparent focus: browsing moves only the opaque marker.
// Editing adds an editor-local tonal background and lower line.
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
    color: editing ? Theme.withAlpha(ringColor, 0.22) : "transparent"
    border.width: 0
    border.color: ringColor
    visible: active
    z: 100
    Accessible.ignored: true

    Rectangle {
        objectName: "editingFocusLine"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.spacingXs
        anchors.rightMargin: Theme.spacingXs
        height: 2
        color: feedback.ringColor
        visible: feedback.editing
    }

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
