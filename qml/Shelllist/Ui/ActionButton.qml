import QtQuick

Rectangle {
    id: control

    property string label: ""
    property string icon: ""
    property string hotkey: ""
    property string tone: "normal"
    property color backgroundColor: tone === "accent" ? Theme.accent
        : (tone === "active" ? Theme.active
        : (tone === "danger" ? Theme.danger
        : (tone === "warning" ? Theme.warning : Theme.controlBackground)))
    property color borderColor: tone === "normal" ? Theme.controlBorder : backgroundColor
    property color labelColor: tone === "accent" ? Theme.accentText
        : (tone === "active" ? Theme.activeText
        : (tone === "danger" ? Theme.dangerText
        : (tone === "warning" ? Theme.warningText : Theme.text)))

    signal clicked

    implicitHeight: Theme.controlHeight
    radius: Theme.controlRadius
    color: !enabled ? backgroundColor
        : (area.pressed ? Theme.mix(backgroundColor, labelColor, 0.14)
        : (area.containsMouse ? Theme.mix(backgroundColor, labelColor, 0.08) : backgroundColor))
    border.color: activeFocus ? Theme.strongBorder : borderColor
    border.width: 1
    opacity: enabled ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: enabled

    Keys.onReturnPressed: function (event) { control.clicked(); event.accepted = true; }
    Keys.onEnterPressed: function (event) { control.clicked(); event.accepted = true; }
    Keys.onSpacePressed: function (event) { control.clicked(); event.accepted = true; }

    ControlLabel {
        anchors.centerIn: parent
        label: control.label
        icon: control.icon
        hotkey: control.hotkey
        iconColor: control.labelColor
        labelColor: control.labelColor
    }

    ControlPointerArea { id: area; focusTarget: control; onClicked: control.clicked() }
}
