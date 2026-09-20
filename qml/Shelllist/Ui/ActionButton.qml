import QtQuick
import QtQuick.Controls as Controls

ActionControl {
    id: control

    property string label: ""
    accessibleName: label
    property string icon: ""
    property int iconSize: Theme.iconSizeSmall
    property string hotkey: ""
    property string toolTip: ""
    property string tone: "normal"
    property color backgroundColor: tone === "accent" ? Theme.accent : (tone === "active" ? Theme.active : (tone === "danger" ? Theme.danger : (tone === "warning" ? Theme.warning : Theme.controlBackground)))
    property color borderColor: tone === "normal" ? Theme.controlBorder : backgroundColor
    property color hoverBackgroundColor: Theme.mix(backgroundColor, labelColor, 0.08)
    property color pressedBackgroundColor: Theme.mix(backgroundColor, labelColor, 0.14)
    property color labelColor: tone === "accent" ? Theme.accentText : (tone === "active" ? Theme.activeText : (tone === "danger" ? Theme.dangerText : (tone === "warning" ? Theme.warningText : Theme.text)))
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed
    readonly property string interactionState: !enabled || !interactive ? "disabled" : (pressed ? "pressed" : (hovered || activeFocus ? "highlighted" : "flat"))

    implicitHeight: Theme.controlHeight
    radius: Theme.controlRadius
    color: interactionState === "pressed" ? pressedBackgroundColor : (interactionState === "highlighted" ? hoverBackgroundColor : backgroundColor)
    border.color: activeFocus ? Theme.strongBorder : borderColor
    border.width: 1
    opacity: enabled && interactive ? 1.0 : Theme.disabledOpacity
    ControlLabel {
        anchors.centerIn: parent
        label: control.label
        icon: control.icon
        hotkey: control.hotkey
        iconColor: control.labelColor
        iconSize: control.iconSize
        labelColor: control.labelColor
    }

    StateLayer {
        id: area
        focusTarget: control
        interactive: control.interactive
        radius: control.radius
        stateColor: control.labelColor
        showStateBackground: false
        onClicked: control.activate()
    }

    Controls.ToolTip.visible: area.containsMouse && control.toolTip.length > 0
    Controls.ToolTip.text: control.toolTip
    Controls.ToolTip.delay: 450
}
