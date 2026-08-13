import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row

    required property int index
    required property ChooserListPane listPane
    property real rowHeight: listPane.delegateHeight
    property real uiScale: listPane.densityScale
    property int selectedIndex: listPane.selectedIndex
    property bool selectionFocused: listPane.listFocused
    property bool detailsOpen: listPane.chooserController.detailsOpen
    property string accessibleName: ""
    property real trailingActionWidth: 0
    readonly property bool selected: index === selectedIndex
    default property alias content: rowContent.data

    signal picked(int rowIndex)
    signal primaryRequested
    signal detailsToggled(int rowIndex)

    onPicked: function (rowIndex) { listPane.pick(rowIndex); }
    onPrimaryRequested: listPane.chooserController.primarySelected()
    onDetailsToggled: function (rowIndex) { listPane.toggleDetails(rowIndex); }

    function scaled(value) {
        return Math.round(value * uiScale);
    }

    width: ListView.view.width
    height: rowHeight
    radius: selected ? Theme.cardRadius : 0
    color: selected ? Theme.selected : (rowMouse.pressed ? Theme.pressed : (rowMouse.containsMouse ? Theme.hover : "transparent"))
    border.color: selected && selectionFocused ? Theme.strongBorder : "transparent"
    border.width: selected && selectionFocused ? 1 : 0
    Accessible.role: Accessible.ListItem
    Accessible.name: accessibleName
    Accessible.selected: selected
    Accessible.onPressAction: row.picked(row.index)

    Keys.onReturnPressed: function (event) { row.primaryRequested(); event.accepted = true; }
    Keys.onEnterPressed: function (event) { row.primaryRequested(); event.accepted = true; }
    Keys.onSpacePressed: function (event) { row.picked(row.index); event.accepted = true; }
    Keys.onRightPressed: function (event) { row.detailsToggled(row.index); event.accepted = true; }

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
        color: row.selected || chevronHover.hovered ? Theme.accent : Theme.mutedText
        font.family: Theme.iconFontFamily
        font.pixelSize: Math.max(Theme.iconSizeSmall, row.scaled(Theme.iconSize))

        HoverHandler { id: chevronHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: row.detailsToggled(row.index) }
    }

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        anchors.rightMargin: row.scaled(38) + row.trailingActionWidth
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.picked(row.index)
        onDoubleClicked: row.primaryRequested()
    }
}
