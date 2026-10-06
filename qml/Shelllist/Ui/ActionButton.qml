import QtQuick

// Command labels are nonvisual. Explanations belong beside the circular control,
// or in a named command menu; changing the label never changes hit geometry.
PointerActionControl {
    id: control

    property string label: ""
    accessibleName: label
    property string icon: ""
    property url iconSource: ""
    property int iconSize: Math.round((sizeRole === "primary" ? Theme.primaryActionIconSize : Theme.secondaryActionIconSize) * uiScale)
    property string sizeRole: "normal"
    property real uiScale: 1
    // Nonvisual metadata; no hover tooltip is rendered.
    property string toolTip: ""
    Accessible.description: [toolTip, surfaceShortcut ? qsTr("Shortcut %1").arg(surfaceShortcut) : ""].filter(Boolean).join(". ")
    property string tone: "normal"
    property color backgroundColor: tone === "accent" ? Theme.accent : (tone === "active" ? Theme.active : (tone === "danger" ? Theme.danger : (tone === "warning" ? Theme.warning : Theme.controlBackground)))
    property color borderColor: tone === "normal" ? Theme.controlBorder : backgroundColor
    property color hoverBackgroundColor: Theme.mix(backgroundColor, labelColor, 0.08)
    property color pressedBackgroundColor: Theme.mix(backgroundColor, labelColor, 0.14)
    property color labelColor: tone === "accent" ? Theme.accentText : (tone === "active" ? Theme.activeText : (tone === "danger" ? Theme.dangerText : (tone === "warning" ? Theme.warningText : Theme.text)))
    readonly property string interactionState: !enabled || !interactive ? "disabled" : (pressed ? "pressed" : (hovered || highlighted ? "highlighted" : "flat"))

    implicitHeight: Math.round((sizeRole === "primary" ? Theme.primaryActionHeight : sizeRole === "secondary" ? Theme.secondaryActionHeight : Theme.controlHeight) * uiScale)
    implicitWidth: implicitHeight
    radius: Math.min(width, height) / 2
    readonly property color stateBackgroundColor: interactionState === "pressed" ? pressedBackgroundColor : (interactionState === "highlighted" ? hoverBackgroundColor : backgroundColor)
    color: stateBackgroundColor
    border.color: borderColor
    focusRingColor: labelColor
    border.width: 1
    opacity: enabled && interactive ? 1.0 : Theme.disabledOpacity
    ControlLabel {
        objectName: "actionLabel"
        anchors.centerIn: parent
        label: ""
        hotkey: ""
        icon: control.icon
        iconSource: control.iconSource
        iconColor: control.labelColor
        iconSize: Math.min(control.iconSize, Math.min(control.width, control.height) - 8)
        labelColor: control.labelColor
    }
}
