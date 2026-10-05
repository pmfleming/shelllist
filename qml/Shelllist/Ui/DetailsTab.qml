import QtQuick

PointerActionControl {
    id: tab

    property string label: ""
    property string icon: ""
    property string hotkey: ""
    property bool selected: false

    accessibleName: label
    Accessible.selected: selected
    Accessible.role: Accessible.PageTab

    activeFocusOnTab: false
    pointerEnabled: enabled
    color: selected ? Theme.selected : (enabled && pointerPressed ? Theme.pressed : (enabled && (hovered || activeFocus) ? Theme.hover : "transparent"))
    border.width: 0
    opacity: enabled ? 1.0 : Theme.disabledOpacity

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingMd
        height: 3
        radius: 2
        color: Theme.accent
        visible: tab.selected
    }

    ControlLabel {
        anchors.centerIn: parent
        label: tab.icon ? "" : tab.label
        icon: tab.icon
        hotkey: tab.hotkey
        iconColor: tab.selected ? Theme.accent : Theme.mutedText
        labelColor: tab.selected ? Theme.accent : Theme.text
        labelWeight: tab.selected ? Theme.fontWeightDemiBold : Theme.fontWeightRegular
    }
}
