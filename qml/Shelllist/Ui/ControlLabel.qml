import QtQuick
import "UiText.js" as UiText

Row {
    id: controlLabel

    required property string label
    required property string icon
    required property string hotkey
    property url iconSource: ""
    property color iconColor: Theme.text
    property int iconSize: Theme.iconSizeSmall
    property color labelColor: Theme.text
    property int labelWeight: Theme.fontWeightRegular
    property int labelPixelSize: Theme.fontSizeBody
    property real maximumWidth: -1

    spacing: Theme.spacingSm
    IconTile {
        objectName: "controlIcon"
        visible: controlLabel.icon.length > 0 || controlLabel.iconSource.toString().length > 0
        anchors.verticalCenter: parent.verticalCenter
        width: controlLabel.iconSize
        height: controlLabel.iconSize
        icon: controlLabel.icon
        iconSource: controlLabel.iconSource
        iconColor: controlLabel.iconColor
        iconSize: controlLabel.iconSize
    }
    ThemeText {
        visible: controlLabel.label.length > 0
        anchors.verticalCenter: parent.verticalCenter
        text: controlLabel.hotkey ? UiText.highlightHotkey(controlLabel.label, controlLabel.hotkey) : controlLabel.label
        textFormat: controlLabel.hotkey ? Text.RichText : Text.PlainText
        width: controlLabel.maximumWidth < 0 ? implicitWidth : Math.min(implicitWidth, Math.max(0, controlLabel.maximumWidth - (controlLabel.icon.length || controlLabel.iconSource.toString().length ? controlLabel.iconSize + controlLabel.spacing : 0)))
        elide: Text.ElideRight
        font.pixelSize: controlLabel.labelPixelSize
        color: controlLabel.labelColor
        font.weight: controlLabel.labelWeight
    }
}
