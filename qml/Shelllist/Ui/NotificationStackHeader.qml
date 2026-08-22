import QtQuick

Row {
    id: header

    property string appName: "Notifications"
    property int count: 0
    property bool expanded: false
    property bool clearEnabled: true
    property bool expandVisible: count > 1

    signal clearRequested
    signal expandedToggled

    height: 30
    spacing: Theme.spacingSm

    Text {
        width: parent.width - countLabel.width - clearButton.width - expandButton.width
            - parent.spacing * 3
        anchors.verticalCenter: parent.verticalCenter
        text: header.appName
        color: Theme.text
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        font.weight: Theme.fontWeightDemiBold
    }
    Text {
        id: countLabel
        anchors.verticalCenter: parent.verticalCenter
        text: String(header.count)
        color: Theme.mutedText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeCaption
    }
    FlatIconButton {
        id: clearButton
        width: 28
        height: 28
        icon: "󰩹"
        enabled: header.clearEnabled
        accessibleName: "Clear notifications from " + header.appName
        toolTip: accessibleName
        onClicked: header.clearRequested()
    }
    FlatIconButton {
        id: expandButton
        visible: header.expandVisible
        width: visible ? 28 : 0
        height: 28
        icon: header.expanded ? "󰅀" : "󰅂"
        accessibleName: header.expanded
            ? "Collapse notification stack" : "Expand notification stack"
        toolTip: accessibleName
        onClicked: header.expandedToggled()
    }
}
