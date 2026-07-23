import QtQuick

Rectangle {
    id: control

    property bool checked: false
    property color checkedColor: Theme.accent
    property color uncheckedColor: Theme.border

    signal toggled(bool checked)

    implicitWidth: 56
    implicitHeight: Theme.controlHeight
    radius: Theme.controlRadius
    color: area.pressed ? Theme.pressed : (area.containsMouse ? Theme.hover : "transparent")
    border.color: activeFocus ? Theme.strongBorder : "transparent"
    border.width: 1
    opacity: enabled ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: enabled

    Keys.onReturnPressed: function (event) { control.toggle(); event.accepted = true; }
    Keys.onEnterPressed: function (event) { control.toggle(); event.accepted = true; }
    Keys.onSpacePressed: function (event) { control.toggle(); event.accepted = true; }

    function toggle() {
        if (enabled)
            toggled(!checked);
    }

    TogglePill {
        readonly property real visualScale: Math.min(control.width / 56, control.height / Theme.controlHeight)

        anchors.centerIn: parent
        width: Math.round(42 * visualScale)
        height: Math.round(24 * visualScale)
        checked: control.checked
        checkedColor: control.checkedColor
        uncheckedColor: control.uncheckedColor
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: control.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: control.forceActiveFocus()
        onClicked: control.toggle()
    }
}
