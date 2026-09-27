import QtQuick

ActionControl {
    id: control

    property string label: ""
    accessibleName: label
    property string icon: ""
    property int iconSize: Theme.iconSizeSmall
    property string hotkey: ""
    // Transitional nonvisual metadata; no tooltip or focus label is rendered.
    property string toolTip: ""
    Accessible.description: toolTip
    property string tone: "normal"
    property color backgroundColor: tone === "accent" ? Theme.accent : (tone === "active" ? Theme.active : (tone === "danger" ? Theme.danger : (tone === "warning" ? Theme.warning : Theme.controlBackground)))
    property color borderColor: tone === "normal" ? Theme.controlBorder : backgroundColor
    property color hoverBackgroundColor: Theme.mix(backgroundColor, labelColor, 0.08)
    property color pressedBackgroundColor: Theme.mix(backgroundColor, labelColor, 0.14)
    property color labelColor: tone === "accent" ? Theme.accentText : (tone === "active" ? Theme.activeText : (tone === "danger" ? Theme.dangerText : (tone === "warning" ? Theme.warningText : Theme.text)))
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: enabled && interactive && (area.pressed || keyboardPressed)
    readonly property string interactionState: !enabled || !interactive ? "disabled" : (pressed ? "pressed" : (hovered || activeFocus ? "highlighted" : "flat"))

    implicitHeight: Theme.controlHeight
    radius: Math.max(0, Math.min(Math.min(width, height) / 2, shape.value))
    readonly property color stateBackgroundColor: interactionState === "pressed" ? pressedBackgroundColor : (interactionState === "highlighted" ? hoverBackgroundColor : backgroundColor)
    color: stateBackgroundColor
    border.color: borderColor
    focusRingColor: labelColor
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

    ExpressiveMotion {
        id: shape
        target: control.pressed ? Math.min(Theme.pressedCornerRadius, Math.min(control.width, control.height) / 2) : Math.min(control.width, control.height) / 2
    }

    // Shape and solid state color replace the unbounded decorative ripple.
    // Neither changes the pointer target or delays activation.
    ControlPointerArea {
        id: area
        focusTarget: control
        enabled: control.enabled && control.interactive
        onClicked: control.activate()
    }
}
