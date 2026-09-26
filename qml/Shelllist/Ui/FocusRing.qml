import QtQuick

// Focus is state, not decoration: no animation, input handlers or layout changes.
// Draw inside the owner so clipped rows and rounded containers retain the ring.
Rectangle {
    property bool active: false
    property real cornerRadius: Theme.controlRadius
    property color ringColor: Theme.text

    objectName: "focusRing"
    anchors.fill: parent
    anchors.margins: Theme.focusRingInset
    radius: Math.max(0, cornerRadius - Theme.focusRingInset)
    color: "transparent"
    border.color: ringColor
    border.width: Theme.focusRingWidth
    visible: active
    z: 100
    Accessible.ignored: true
}
