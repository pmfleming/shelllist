import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: button

    required property string label
    property bool checked: false
    signal triggered

    width: Math.max(38, labelText.implicitWidth + 18)
    height: 34
    radius: Ui.Theme.controlRadius
    color: checked ? Ui.Theme.selected
        : pointer.hovered ? Ui.Theme.hover : Ui.Theme.controlBackground
    border.color: checked ? Ui.Theme.accent
        : activeFocus ? Ui.Theme.strongBorder : Ui.Theme.controlBorder
    opacity: enabled ? 1 : Ui.Theme.disabledOpacity
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: if (enabled) triggered()

    Keys.onReturnPressed: function (event) { triggered(); event.accepted = true; }
    Keys.onEnterPressed: function (event) { triggered(); event.accepted = true; }
    Keys.onSpacePressed: function (event) { triggered(); event.accepted = true; }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: button.label
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeBody
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Ui.StateLayer {
        id: pointer
        focusTarget: button
        radius: button.radius
        showStateBackground: false
        interactive: button.enabled
        onClicked: button.triggered()
    }
}
