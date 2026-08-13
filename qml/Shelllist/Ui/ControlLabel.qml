import QtQuick
import "UiText.js" as UiText

Row {
    id: controlLabel

    required property string label
    required property string icon
    required property string hotkey
    property color iconColor: Theme.text
    property int iconSize: Theme.iconSizeSmall
    property color labelColor: Theme.text
    property int labelWeight: Theme.fontWeightRegular

    spacing: Theme.spacingSm
    Text {
        visible: controlLabel.icon.length > 0
        anchors.verticalCenter: parent.verticalCenter
        text: controlLabel.icon
        color: controlLabel.iconColor
        font.family: Theme.iconFontFamily
        font.pixelSize: controlLabel.iconSize
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
