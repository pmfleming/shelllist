import QtQuick.Layouts

DetailCard {
    id: card

    default property alias columnContent: contentLayout.data
    property int contentSpacing: Theme.spacingSm
    readonly property real contentImplicitHeight: contentLayout.implicitHeight

    // Content-sized cards need stable padding: deriving it from height would
    // feed the layout's implicit size back into its own inputs.
    verticalContentPadding: Theme.spacingMd
    headingSpacing: title.length > 0 ? Theme.spacingMd : 0
    implicitHeight: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: card.contentSpacing
    }
}
