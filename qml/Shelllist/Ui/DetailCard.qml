import QtQuick

Rectangle {
    id: card

    property string title: ""
    property var entries: null
    property real contentPadding: Math.max(Theme.spacingMd, Math.min(Theme.spacingLg, height * 0.06))
    property real verticalContentPadding: Math.max(Theme.spacingSm, Math.min(contentPadding, height * 0.05))
    property real headingSpacing: title.length > 0
        ? Math.max(Theme.spacingXs, Math.min(Theme.spacingMd, height * 0.04))
        : 0
    default property alias content: contentSlot.data

    width: parent ? parent.width : 0
    radius: Theme.cardRadius
    color: Theme.withAlpha(Theme.surfaceRaised, 0.96)
    border.color: Theme.mix(Theme.border, Theme.text, 0.12)
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.leftMargin: card.contentPadding
        anchors.rightMargin: card.contentPadding
        anchors.topMargin: card.verticalContentPadding
        anchors.bottomMargin: card.verticalContentPadding
        spacing: card.headingSpacing

        Text {
            id: heading

            visible: card.title.length > 0
            text: card.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeHeading
            font.weight: Theme.fontWeightBold
        }

        Item {
            id: contentSlot

            width: parent.width
            height: Math.max(0, parent.height - heading.height - parent.spacing)

            DetailGrid {
                visible: card.entries !== null
                entries: card.entries || []
            }
        }
    }
}
