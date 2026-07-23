import QtQuick

Flickable {
    id: page

    default property alias cards: cardColumn.data
    property int cardSpacing: Theme.spacingMd

    contentWidth: width
    contentHeight: cardColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    clip: true

    Column {
        id: cardColumn
        width: page.width
        spacing: page.cardSpacing
    }
}
