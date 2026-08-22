import QtQuick
import QtQuick.Layouts

Rectangle {
    id: frame

    property string label: ""
    property string valueText: ""
    property color lineColor: Theme.accent
    property int graphHeight: 88
    default property alias plot: plotArea.data

    signal repaintRequested

    Layout.fillWidth: true
    Layout.preferredHeight: graphHeight
    radius: Theme.cardRadius
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    onWidthChanged: repaintRequested()
    onHeightChanged: repaintRequested()

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.topMargin: 7
        text: frame.label
        color: Theme.mutedText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Theme.fontWeightDemiBold
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 10
        anchors.topMargin: 7
        text: frame.valueText
        color: frame.lineColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Theme.fontWeightDemiBold
    }

    Item {
        id: plotArea
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 27
        anchors.bottomMargin: 9
    }
}
