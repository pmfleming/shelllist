import QtQuick

ActionButton {
    property color flatIconColor: Theme.mutedText
    property color disabledIconColor: Theme.text
    property color highlightedBackgroundColor: Theme.accent
    property color highlightedIconColor: Theme.accentText
    property color pressedColor: Theme.mix(highlightedBackgroundColor, Theme.window, 0.18)
    property color animatedBackgroundColor: stateBackgroundColor

    // Focus bypasses decoration, including a hover animation already running.
    // Keep the matching foreground/background pair even while busy.
    color: highlighted ? (pressed ? pressedBackgroundColor : highlightedBackgroundColor) : animatedBackgroundColor

    // Unfilled glyphs need more contrast than filled disabled circles.
    opacity: enabled && interactive ? 1.0 : 0.65
    label: ""
    tone: "normal"
    backgroundColor: "transparent"
    border.width: 0
    borderColor: "transparent"
    // Disabled is still an unfilled surface, not an accent-filled highlight.
    labelColor: highlighted || interactionState === "pressed" || interactionState === "highlighted" ? highlightedIconColor : (interactionState === "disabled" ? disabledIconColor : flatIconColor)
    hoverBackgroundColor: highlightedBackgroundColor
    pressedBackgroundColor: pressedColor

    InteractiveBehavior on animatedBackgroundColor {
        duration: Theme.animationFast
        easingType: Easing.Linear
    }
}
