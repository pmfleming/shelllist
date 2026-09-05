import QtQuick.Layouts

DetailCard {
    id: card

    default property alias columnContent: contentLayout.data
    property int contentSpacing: Theme.spacingSm
    readonly property real contentImplicitHeight: contentLayout.implicitHeight

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: card.contentSpacing
    }
}
