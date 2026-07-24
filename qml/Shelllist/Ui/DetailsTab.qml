import QtQuick

Rectangle {
    id: tab

    property string label: ""
    property string icon: ""
    property string hotkey: ""
    property bool selected: false

    signal clicked

    color: selected ? Theme.selected
        : (enabled && area.pressed ? Theme.pressed
        : (enabled && area.containsMouse ? Theme.hover : "transparent"))
    border.color: activeFocus ? Theme.strongBorder : "transparent"
    border.width: 1
    opacity: enabled ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: enabled

    Keys.onReturnPressed: function (event) { tab.clicked(); event.accepted = true; }
    Keys.onEnterPressed: function (event) { tab.clicked(); event.accepted = true; }
    Keys.onSpacePressed: function (event) { tab.clicked(); event.accepted = true; }

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
        label: tab.label
        icon: tab.icon
        hotkey: tab.hotkey
        iconColor: tab.selected ? Theme.accent : Theme.mutedText
        labelColor: tab.selected ? Theme.accent : Theme.text
        labelWeight: tab.selected ? Theme.fontWeightDemiBold : Theme.fontWeightRegular
    }

    ControlPointerArea { id: area; focusTarget: tab; onClicked: tab.clicked() }
}
