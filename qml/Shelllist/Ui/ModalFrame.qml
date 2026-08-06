import QtQuick

Rectangle {
    id: frame

    property string title: ""
    property string detail: ""
    property real maximumCardWidth: 560
    readonly property bool compact: height < 720
    property real minimumOuterMargin: compact ? Theme.spacingSm : Theme.spacingLg
    property real cardPadding: compact ? Theme.spacingMd : Theme.spacingLg
    property real bodySpacing: compact ? Theme.spacingSm : Theme.spacingMd
    default property alias body: bodyColumn.data

    anchors.fill: parent
    z: 10
    color: Theme.overlay

    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        width: Math.min(parent.width - 2 * frame.minimumOuterMargin, frame.maximumCardWidth)
        implicitHeight: contentColumn.implicitHeight + 2 * frame.cardPadding
        height: Math.min(parent.height - 2 * frame.minimumOuterMargin, implicitHeight)
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        radius: Theme.windowRadius
        color: Theme.surface
        border.color: Theme.strongBorder
        border.width: 1
        clip: true

        Column {
            id: contentColumn

            x: frame.cardPadding
            y: frame.cardPadding
            width: parent.width - 2 * frame.cardPadding
            spacing: frame.bodySpacing

            Text {
                width: parent.width
                visible: frame.title.length > 0
                text: frame.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: frame.compact ? Theme.fontSizeHeading : Theme.fontSizeDisplay
                font.weight: Theme.fontWeightBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: frame.detail.length > 0
                text: frame.detail
                color: Theme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                wrapMode: Text.Wrap
                maximumLineCount: frame.compact ? 3 : 5
                elide: Text.ElideRight
            }

            Column {
                id: bodyColumn

                width: parent.width
                spacing: frame.bodySpacing
            }
        }
    }
}
