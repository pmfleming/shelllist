import QtQuick
import Shelllist.Ui as Ui

Ui.ActionControl {
    id: button

    required property string label
    property bool checked: false
    signal triggered

    width: Math.max(38, labelText.implicitWidth + 18)
    height: 34
    radius: Ui.Theme.controlRadius
    color: checked ? Ui.Theme.selected : (pointer.hovered || highlighted) ? Ui.Theme.hover : Ui.Theme.controlBackground
    border.color: checked ? Ui.Theme.accent : Ui.Theme.controlBorder
    opacity: enabled ? 1 : Ui.Theme.disabledOpacity
    Accessible.role: Accessible.Button
    Accessible.name: label
    onClicked: triggered()

    Ui.ThemeText {
        id: labelText
        anchors.centerIn: parent
        text: button.label
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Ui.StateLayer {
        id: pointer
        focusTarget: button
        radius: button.radius
        showStateBackground: false
        interactive: button.enabled
        onClicked: button.activate()
    }
}
