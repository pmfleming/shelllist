import QtQuick

Flickable {
    id: page

    // Direct children are positioned by the Column. Give them width and
    // explicit/implicit height, not vertical anchors (including anchors.fill).
    // Anchor content inside an unanchored Item/DetailCard when it needs a slot.
    default property alias cards: cardColumn.data
    property int cardSpacing: Theme.verticalSpacing(Theme.spacingMd, Theme.densityScale(height, 0))

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
