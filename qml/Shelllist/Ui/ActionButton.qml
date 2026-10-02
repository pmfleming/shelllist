import QtQuick

ActionControl {
    id: control

    property string label: ""
    accessibleName: label
    property string icon: ""
    property bool iconOnly: icon.length > 0
    property int iconSize: Theme.iconSizeSmall
    property string hotkey: ""
    property string accessKey: ""
    // Read the owning boundary directly; delegate recreation must not restore
    // an obsolete shortcut binding onto a surviving primary button.
    readonly property DetailsNavigation shortcutNavigation: accessKey ? owningNavigation(parent) : null
    readonly property string surfaceShortcut: shortcutNavigation ? shortcutNavigation.shortcutFor(control) : ""
    function owningNavigation(item: Item): DetailsNavigation {
        while (item) {
            if (item instanceof DetailsNavigation) return item as DetailsNavigation;
            item = item.parent;
        }
        return null;
    }
    // Opt-in surface hierarchy; ordinary content buttons keep their sizing.
    property string sizeRole: "normal"
    property real uiScale: 1
    readonly property int labelPixelSize: Math.round(Theme.fontSizeBody * uiScale)
    readonly property int horizontalPadding: Math.round(Theme.actionHorizontalPadding * uiScale)
    // Transitional nonvisual metadata; no tooltip or focus label is rendered.
    property string toolTip: ""
    Accessible.description: [toolTip, surfaceShortcut ? qsTr("Shortcut %1").arg(surfaceShortcut) : ""].filter(Boolean).join(". ")
    property string tone: "normal"
    property color backgroundColor: tone === "accent" ? Theme.accent : (tone === "active" ? Theme.active : (tone === "danger" ? Theme.danger : (tone === "warning" ? Theme.warning : Theme.controlBackground)))
    property color borderColor: tone === "normal" ? Theme.controlBorder : backgroundColor
    property color hoverBackgroundColor: Theme.mix(backgroundColor, labelColor, 0.08)
    property color pressedBackgroundColor: Theme.mix(backgroundColor, labelColor, 0.14)
    property color labelColor: tone === "accent" ? Theme.accentText : (tone === "active" ? Theme.activeText : (tone === "danger" ? Theme.dangerText : (tone === "warning" ? Theme.warningText : Theme.text)))
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: enabled && interactive && (area.pressed || keyboardPressed)
    readonly property string interactionState: !enabled || !interactive ? "disabled" : (pressed ? "pressed" : (hovered || highlighted ? "highlighted" : "flat"))

    implicitHeight: Math.round((sizeRole === "primary" ? Theme.primaryActionHeight : sizeRole === "secondary" ? Theme.secondaryActionHeight : Theme.controlHeight) * uiScale)
    implicitWidth: sizeRole === "normal" ? 0 : iconOnly ? implicitHeight : Math.ceil(labelMetrics.advanceWidth) + horizontalPadding * 2 + (icon.length ? iconSize + Theme.spacingSm : 0)
    TextMetrics {
        id: labelMetrics
        text: control.sizeRole === "normal" ? "" : control.label
        font.family: Theme.fontFamily
        font.pixelSize: control.labelPixelSize
        font.weight: control.sizeRole === "primary" ? Theme.fontWeightMedium : Theme.fontWeightRegular
    }
    radius: Math.max(0, Math.min(Math.min(width, height) / 2, shape.value))
    readonly property color stateBackgroundColor: interactionState === "pressed" ? pressedBackgroundColor : (interactionState === "highlighted" ? hoverBackgroundColor : backgroundColor)
    color: stateBackgroundColor
    border.color: borderColor
    focusRingColor: labelColor
    border.width: 1
    opacity: enabled && interactive ? 1.0 : Theme.disabledOpacity
    ControlLabel {
        objectName: "actionLabel"
        anchors.centerIn: parent
        label: control.iconOnly ? "" : control.label
        icon: control.icon
        hotkey: control.hotkey
        iconColor: control.labelColor
        iconSize: control.iconSize
        labelColor: control.labelColor
        labelPixelSize: control.labelPixelSize
        labelWeight: control.sizeRole === "primary" ? Theme.fontWeightMedium : Theme.fontWeightRegular
        maximumWidth: control.sizeRole === "normal" ? -1 : Math.max(0, control.width - control.horizontalPadding * 2)
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
