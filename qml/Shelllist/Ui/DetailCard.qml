import QtQuick

Rectangle {
    id: card

    property string title: ""
    property real contentPadding: Math.max(Theme.spacingMd, Math.min(Theme.spacingLg, height * 0.06))
    default property alias content: contentSlot.data

    width: parent ? parent.width : 0
    radius: Theme.cardRadius
    color: Theme.withAlpha(Theme.surfaceRaised, 0.96)
    border.color: Theme.mix(Theme.border, Theme.text, 0.12)
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: card.contentPadding
        spacing: card.title.length > 0 ? Theme.spacingMd : 0

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
        }
    }
}
