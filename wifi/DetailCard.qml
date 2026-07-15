import QtQuick
import "."

Rectangle {
    id: card

    property string title: ""
    property real contentPadding: Math.max(12, Math.min(18, height * 0.06))
    default property alias content: contentSlot.data

    width: parent ? parent.width : 0
    radius: Theme.cardRadius
    color: Theme.withAlpha(Theme.surfaceRaised, 0.96)
    border.color: Theme.mix(Theme.border, Theme.text, 0.12)
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: card.contentPadding
        spacing: card.title.length > 0 ? 12 : 0

        Text {
            id: heading

            visible: card.title.length > 0
            height: visible ? implicitHeight : 0
            text: card.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.bold: true
        }

        Item {
            id: contentSlot

            width: parent.width
            height: Math.max(0, parent.height - heading.height - parent.spacing)
        }
    }
}
