import QtQuick
import QtQuick.Controls as Controls

Rectangle {
    id: control

    property string label: ""
    property string accessibleName: label
    property string icon: ""
    property string hotkey: ""
    property string toolTip: ""
    property string tone: "normal"
    property color backgroundColor: tone === "accent" ? Theme.accent
        : (tone === "active" ? Theme.active
        : (tone === "danger" ? Theme.danger
        : (tone === "warning" ? Theme.warning : Theme.controlBackground)))
    property color borderColor: tone === "normal" ? Theme.controlBorder : backgroundColor
    property color hoverBackgroundColor: Theme.mix(backgroundColor, labelColor, 0.08)
    property color pressedBackgroundColor: Theme.mix(backgroundColor, labelColor, 0.14)
    property color labelColor: tone === "accent" ? Theme.accentText
        : (tone === "active" ? Theme.activeText
        : (tone === "danger" ? Theme.dangerText
        : (tone === "warning" ? Theme.warningText : Theme.text)))

    signal clicked

    implicitHeight: Theme.controlHeight
    radius: Theme.controlRadius
    color: !enabled ? backgroundColor
        : (area.pressed ? pressedBackgroundColor
        : (area.containsMouse ? hoverBackgroundColor : backgroundColor))
    border.color: activeFocus ? Theme.strongBorder : borderColor
    border.width: 1
    opacity: enabled ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: if (enabled) control.clicked()

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

    Controls.ToolTip.visible: area.containsMouse && control.toolTip.length > 0
    Controls.ToolTip.text: control.toolTip
    Controls.ToolTip.delay: 450
}
