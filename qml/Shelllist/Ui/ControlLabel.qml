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
    GlyphLabel {
        visible: controlLabel.icon.length > 0
        anchors.verticalCenter: parent.verticalCenter
        glyph: controlLabel.icon
        color: controlLabel.iconColor
        font.pixelSize: controlLabel.iconSize
    }
    ThemeText {
        visible: controlLabel.label.length > 0
        anchors.verticalCenter: parent.verticalCenter
        text: UiText.highlightHotkey(controlLabel.label, controlLabel.hotkey)
        textFormat: Text.RichText
        color: controlLabel.labelColor
        font.weight: controlLabel.labelWeight
    }
}
