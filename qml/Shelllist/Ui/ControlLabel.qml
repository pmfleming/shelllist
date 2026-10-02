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
    property int labelPixelSize: Theme.fontSizeBody
    property real maximumWidth: -1

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
        text: controlLabel.hotkey ? UiText.highlightHotkey(controlLabel.label, controlLabel.hotkey) : controlLabel.label
        textFormat: controlLabel.hotkey ? Text.RichText : Text.PlainText
        width: controlLabel.maximumWidth < 0 ? implicitWidth : Math.min(implicitWidth, Math.max(0, controlLabel.maximumWidth - (controlLabel.icon.length ? controlLabel.iconSize + controlLabel.spacing : 0)))
        elide: Text.ElideRight
        font.pixelSize: controlLabel.labelPixelSize
        color: controlLabel.labelColor
        font.weight: controlLabel.labelWeight
    }
}
