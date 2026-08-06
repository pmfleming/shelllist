import QtQuick
import QtQuick.Layouts

Rectangle {
    id: pane

    required property ChooserController chooserController
    property real densityScale: 1
    property int sectionSpacing: Theme.verticalSpacing(Theme.spacingMd, densityScale)
    property int leftMargin: Math.round(Theme.spacingLg * densityScale)
    property int rightMargin: leftMargin
    property int bottomMargin: 2
    property string emptyText: "Select an item"
    property int emptyFontSize: Theme.fontSizeTitle
    default property alias content: contentColumn.data

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 0
    color: "transparent"
    border.color: "transparent"
    clip: true

    Item {
        anchors.fill: parent
        anchors.leftMargin: pane.leftMargin
        anchors.rightMargin: pane.rightMargin
        anchors.bottomMargin: pane.bottomMargin

        Column {
            id: contentColumn
            visible: pane.chooserController.hasSelection
            anchors.fill: parent
            spacing: pane.sectionSpacing
        }

        CenteredMessage {
            visible: !pane.chooserController.hasSelection
            text: pane.emptyText
            font.pixelSize: pane.emptyFontSize
        }
    }
}
