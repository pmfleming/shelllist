import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row

    required property int index
    required property real rowHeight
    property real uiScale: 1
    property int selectedIndex: 0
    property bool selectionFocused: false
    property bool detailsOpen: false
    readonly property bool selected: index === selectedIndex
    default property alias content: rowContent.data

    signal picked(int rowIndex)
    signal primaryRequested
    signal detailsToggled(int rowIndex)

    function scaled(value) {
        return Math.round(value * uiScale);
    }

    width: ListView.view.width
    height: rowHeight
    radius: selected ? Theme.cardRadius : 0
    color: selected ? Theme.selected : (rowMouse.pressed ? Theme.pressed : (rowMouse.containsMouse ? Theme.hover : "transparent"))
    border.color: selected && selectionFocused ? Theme.strongBorder : "transparent"
    border.width: selected && selectionFocused ? 1 : 0

    Rectangle {
        visible: !row.selected
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: row.scaled(Theme.spacingLg)
        anchors.rightMargin: row.scaled(Theme.spacingLg)
        height: 1
        color: Theme.mix(Theme.border, Theme.text, 0.14)
        opacity: 0.85
    }

    RowLayout {
        id: rowContent

        anchors.fill: parent
        anchors.leftMargin: row.scaled(20)
        anchors.rightMargin: row.scaled(44)
        spacing: row.scaled(10)
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: row.scaled(16)
        width: row.scaled(18)
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: row.selected && row.detailsOpen ? "󰅁" : "󰅂"
        color: row.selected || chevronMouse.containsMouse ? Theme.accent : Theme.mutedText
        font.family: Theme.iconFontFamily
        font.pixelSize: Math.max(Theme.iconSizeSmall, row.scaled(Theme.iconSize))

        MouseArea {
            id: chevronMouse

            anchors.fill: parent
            anchors.margins: -row.scaled(Theme.spacingSm)
            cursorShape: Qt.PointingHandCursor
            onClicked: row.detailsToggled(row.index)
        }
    }

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        anchors.rightMargin: row.scaled(38)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.picked(row.index)
        onDoubleClicked: row.primaryRequested()
    }
}
