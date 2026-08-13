import QtQuick

ActionButton {
    property color flatIconColor: Theme.mutedText
    property color highlightedBackgroundColor: Theme.accent
    property color highlightedIconColor: Theme.accentText
    property color pressedColor: Theme.mix(highlightedBackgroundColor, Theme.window, 0.18)

    label: ""
    tone: "normal"
    backgroundColor: "transparent"
    border.width: 0
    borderColor: "transparent"
    labelColor: interactionState === "flat" ? flatIconColor : highlightedIconColor
    hoverBackgroundColor: highlightedBackgroundColor
    pressedBackgroundColor: pressedColor

    Behavior on color {
        enabled: !Theme.noAnimations
        ColorAnimation { duration: Theme.animationFast }
    }
}
