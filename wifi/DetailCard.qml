import QtQuick

Rectangle {
    id: card

    property string title: ""
    default property alias content: contentSlot.data

    width: parent ? parent.width : 0
    radius: 10
    color: "#0b1320"
    border.color: "#1f2a3a"

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Text {
            visible: card.title.length > 0
            height: visible ? implicitHeight : 0
            text: card.title
            color: "#e5e7eb"
            font.pixelSize: 16
            font.bold: true
        }

        Item {
            id: contentSlot

            width: parent.width
            height: parent.height - (card.title.length > 0 ? 32 : 0)
        }
    }
}
