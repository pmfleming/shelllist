import QtQuick

// Closed values and popup options use the same passive label/icon geometry.
ThemeText {
    id: label
    property alias leadingIcon: leading
    property alias trailingIcon: trailing
    property bool trailingVisible: trailing.glyph.length > 0
    property bool reserveTrailingSpace: false

    leftPadding: leading.glyph.length > 0 ? Theme.formIconSize + Theme.spacingSm : 0
    rightPadding: trailingVisible || reserveTrailingSpace ? Theme.formIconSize + Theme.spacingSm : 0
    font.pixelSize: Theme.formValueSize
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight

    GlyphLabel {
        id: leading
        glyph: ""
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: glyph.length > 0
        font.pixelSize: Theme.formIconSize
        color: label.color
        Accessible.ignored: true
    }
    GlyphLabel {
        id: trailing
        glyph: ""
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: label.trailingVisible
        font.pixelSize: Theme.formIconSize
        color: label.color
        Accessible.ignored: true
    }
}
