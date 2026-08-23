import QtQuick

Text {
    required property string glyph

    text: glyph
    color: Theme.mutedText
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    font.family: Theme.iconFontFamily
    font.pixelSize: Theme.iconSize
}
