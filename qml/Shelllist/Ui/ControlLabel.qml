import QtQuick
import "UiText.js" as UiText

Row {
    id: controlLabel

    property string label
    property string icon
    property string hotkey
    property color iconColor: Theme.text
    property color labelColor: Theme.text
    property int labelWeight: Theme.fontWeightRegular

    spacing: Theme.spacingSm
    Text {
        visible: controlLabel.icon.length > 0
        anchors.verticalCenter: parent.verticalCenter
        text: controlLabel.icon
        color: controlLabel.iconColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSizeSmall
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: UiText.highlightHotkey(controlLabel.label, controlLabel.hotkey)
        textFormat: Text.RichText
        color: controlLabel.labelColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeBody
        font.weight: controlLabel.labelWeight
    }
}
