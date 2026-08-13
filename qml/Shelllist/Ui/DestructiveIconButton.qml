import QtQuick

ActionButton {
    readonly property color flatIconColor: Theme.mutedText
    readonly property color highlightedBackgroundColor: Theme.danger
    readonly property color highlightedIconColor: "#ffffff"
    readonly property color pressedColor: Theme.mix(Theme.danger, Theme.window, 0.22)

    label: ""
    icon: "󰅖"
    tone: "normal"
    backgroundColor: "transparent"
    borderColor: interactionState === "flat" ? "transparent" : highlightedBackgroundColor
    labelColor: interactionState === "flat" ? flatIconColor : highlightedIconColor
    hoverBackgroundColor: highlightedBackgroundColor
    pressedBackgroundColor: pressedColor

    Behavior on color {
        enabled: !Theme.noAnimations
        ColorAnimation { duration: Theme.animationFast }
    }
}
