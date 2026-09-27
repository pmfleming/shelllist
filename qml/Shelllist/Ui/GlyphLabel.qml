import QtQuick
import "MaterialIcons.js" as MaterialIcons

Text {
    required property string glyph

    readonly property string symbol: MaterialIcons.name(glyph)
    text: symbol || glyph
    color: Theme.mutedText
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    font.family: symbol ? Theme.symbolFontFamily : Theme.iconFontFamily
    font.pixelSize: Theme.iconSize
}
