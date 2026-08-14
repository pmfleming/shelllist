import QtQuick.Layouts

DetailCard {
    id: card

    default property alias columnContent: contentLayout.data
    property int contentSpacing: Theme.spacingSm

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: card.contentSpacing
    }
}
