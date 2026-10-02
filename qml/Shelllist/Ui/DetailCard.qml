import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    property string title: ""
    property var entries: null
    readonly property real headingHeight: title.length > 0 ? heading.implicitHeight : 0
    // Horizontal padding must not depend on height: wrapped content can own
    // the card's height, so height -> padding -> text width creates a loop.
    property real contentPadding: Theme.spacingMd
    // Stable in both axes: content-sized grids must not feed height back into padding.
    property real verticalContentPadding: Theme.spacingMd
    property real headingSpacing: title.length > 0 ? Theme.spacingMd : 0
    implicitHeight: (entries !== null ? entryGrid.implicitHeight : 0) + headingHeight + headingSpacing + 2 * verticalContentPadding
    Layout.minimumHeight: implicitHeight
    default property alias content: contentSlot.data

    width: parent ? parent.width : 0
    radius: Theme.cardRadius
    // Opaque container tones establish hierarchy without nested outlines.
    color: Theme.surface
    border.width: 0

    Column {
        anchors.fill: parent
        anchors.leftMargin: card.contentPadding
        anchors.rightMargin: card.contentPadding
        anchors.topMargin: card.verticalContentPadding
        anchors.bottomMargin: card.verticalContentPadding
        spacing: card.headingSpacing

        ThemeText {
            id: heading

            visible: card.title.length > 0
            width: parent.width
            text: card.title
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeHeading
            font.weight: Theme.fontWeightMedium
        }

        Item {
            id: contentSlot

            width: parent.width
            height: Math.max(0, parent.height - card.headingHeight - card.headingSpacing)

            DetailGrid {
                id: entryGrid
                visible: card.entries !== null
                entries: card.entries || []
            }
        }
    }
}
