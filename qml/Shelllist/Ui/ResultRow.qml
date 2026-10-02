import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row

    required property int index
    required property ChooserListPane listPane
    property real rowHeight: listPane.delegateHeight
    property real uiScale: 1
    property int selectedIndex: listPane.selectedIndex
    property bool selectionFocused: listPane.listFocused
    property bool detailsOpen: listPane.chooserController.detailsOpen
    property bool pointerHovered: false
    property bool pointerPressed: false
    property string accessibleName: ""
    property bool primaryEnabled: true
    property bool detailsActionVisible: true
    property string leadingIcon: "󰀻"
    property url leadingIconSource: ""
    property color leadingIconColor: Theme.mutedText
    property Component avatarContent: null
    readonly property int detailSlotWidth: detailsActionVisible ? scaled(30) + 6 : 0
    readonly property bool selected: index === selectedIndex
    default property alias content: rowContent.data

    signal picked(int rowIndex)
    signal primaryRequested
    signal detailsToggled(int rowIndex)

    function pick(rowIndex: int): void {
        listPane.pick(rowIndex);
    }
    onPicked: function (rowIndex) {
        pick(rowIndex);
    }
    onPrimaryRequested: if (primaryEnabled)
        listPane.chooserController.primarySelected()
    onDetailsToggled: function (rowIndex) {
        listPane.toggleDetails(rowIndex);
    }

    function scaled(value) {
        return Math.round(value * uiScale);
    }

    width: ListView.view.width
    height: rowHeight
    radius: selectionShape.value
    topLeftRadius: selected || index === 0 ? Theme.panelRadius : radius
    topRightRadius: topLeftRadius
    bottomLeftRadius: selected || index === listPane.resultCount - 1 ? Theme.panelRadius : radius
    bottomRightRadius: bottomLeftRadius
    ExpressiveMotion {
        id: selectionShape
        target: row.selected ? Theme.panelRadius : 4
    }
    color: selected ? Theme.selected : (pointerPressed ? Theme.mix(Theme.surface, Theme.text, 0.12) : (pointerHovered ? Theme.mix(Theme.surface, Theme.text, 0.08) : Theme.surface))
    FocusRing {
        active: row.selected && row.selectionFocused
        cornerRadius: row.radius
    }
    Accessible.role: Accessible.ListItem
    Accessible.name: accessibleName
    Accessible.selected: selected
    Accessible.onPressAction: row.picked(row.index)

    // ListView can give its current delegate native focus. Use the same route
    // as the view, including printable query text, guards and detail focus.
    Keys.onPressed: function (event) {
        row.listPane.chooserController.navigation.handleListKey(event);
    }

    IconTile {
        id: avatar
        objectName: "resultAvatar"
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: avatarShape.value
        backgroundColor: row.selected ? Theme.accent : Theme.surfaceRaised
        iconColor: row.selected ? Theme.accentText : row.leadingIconColor
        iconSource: row.leadingIconSource
        iconSize: Theme.iconSizeLarge
        border.width: 0
        ExpressiveMotion {
            id: avatarShape
            target: row.selected ? 20 : 12
        }
        GlyphLabel {
            anchors.fill: parent
            visible: !avatar.hasImage && !row.avatarContent
            glyph: row.leadingIcon
            color: avatar.iconColor
            font.pixelSize: Theme.iconSizeLarge
        }
        Loader {
            anchors.fill: parent
            sourceComponent: row.avatarContent
        }
    }

    RowLayout {
        id: rowContent
        z: 1

        anchors.fill: parent
        anchors.leftMargin: 68
        anchors.rightMargin: row.detailSlotWidth + 12
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 12
    }

    FlatIconButton {
        objectName: "resultDetailsAction"
        visible: row.detailsActionVisible && row.selected
        z: 2
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: row.scaled(30)
        height: row.scaled(30)
        icon: row.selected && row.detailsOpen ? "󰅁" : "󰅂"
        iconSize: Math.max(Theme.iconSizeSmall, row.scaled(Theme.iconSize))
        flatIconColor: row.selected ? Theme.accent : Theme.mutedText
        accessibleName: row.selected && row.detailsOpen ? "Collapse details" : "Expand details"
        toolTip: row.selected && row.detailsOpen ? "Collapse details" : "Expand details"
        onClicked: row.detailsToggled(row.index)
    }

    StateLayer {
        anchors.rightMargin: row.selected && row.detailsActionVisible ? 42 : 0
        focusTarget: row
        radius: row.radius
        stateColor: Theme.text
        showStateBackground: false
        onHoveredChanged: row.pointerHovered = hovered
        onPressedChanged: row.pointerPressed = pressed
        onClicked: row.picked(row.index)
        onDoubleClicked: row.primaryRequested()
    }
}
