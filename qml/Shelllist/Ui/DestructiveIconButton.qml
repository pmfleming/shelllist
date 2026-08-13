import QtQuick

ActionButton {
    label: ""
    icon: "󰅖"
    tone: "normal"
    backgroundColor: "transparent"
    borderColor: "transparent"
    labelColor: hovered || pressed ? "#ffffff" : Theme.mutedText
    hoverBackgroundColor: Theme.danger
    pressedBackgroundColor: Theme.mix(Theme.danger, Theme.dangerText, 0.14)
}
