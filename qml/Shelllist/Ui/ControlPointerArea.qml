import QtQuick

MouseArea {
    required property Item focusTarget
    anchors.fill: parent
    enabled: focusTarget.enabled
    hoverEnabled: enabled
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onPressed: focusTarget.forceActiveFocus()
}
