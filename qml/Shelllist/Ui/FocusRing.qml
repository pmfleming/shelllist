import QtQuick

// Historical component name: focus now uses a tonal state layer, not an outline.
// Pointer and keyboard focus share this immediate, input-transparent treatment.
Rectangle {
    property bool active: false
    property real cornerRadius: Theme.controlRadius
    property color ringColor: Theme.accent

    objectName: "focusRing"
    anchors.fill: parent
    anchors.margins: Theme.focusRingInset
    radius: Math.max(0, cornerRadius - Theme.focusRingInset)
    color: Theme.withAlpha(ringColor, 0.12)
    border.width: 0
    visible: active
    z: 100
    Accessible.ignored: true
}
