import QtQuick

IconTile {
    id: tile

    property bool refreshing: false
    property bool refreshEnabled: true

    backgroundColor: Theme.controlBackground
    borderColor: Theme.border
    icon: "󰑐"
    iconColor: refreshing ? Theme.accent : Theme.text
    iconSize: Theme.iconSize
    clickable: true
    enabled: refreshEnabled && !refreshing

    NumberAnimation on iconRotation {
        running: tile.refreshing && !Theme.noAnimations
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: Theme.spinnerDuration
    }
}
