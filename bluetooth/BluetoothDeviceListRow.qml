import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: row

    required property int index
    required property var resultData
    required property real rowHeight
    required property real uiScale
    property int selectedIndex: 0
    property bool detailsOpen: false

    readonly property var device: resultData.payload || ({})
    readonly property bool selected: index === selectedIndex

    signal picked(int rowIndex)
    signal primaryRequested
    signal detailsToggled(int rowIndex)

    function scaled(value) { return Math.round(value * uiScale); }

    width: ListView.view.width
    height: rowHeight
    radius: selected ? Ui.Theme.cardRadius : 0
    color: selected ? Ui.Theme.selected
        : (rowMouse.pressed ? Ui.Theme.pressed
        : (rowMouse.containsMouse ? Ui.Theme.hover : "transparent"))
    border.color: selected ? Ui.Theme.strongBorder : "transparent"
    border.width: selected ? 1 : 0

    Rectangle {
        visible: !row.selected
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: row.scaled(Ui.Theme.spacingLg)
        anchors.rightMargin: row.scaled(Ui.Theme.spacingLg)
        height: 1
        color: Ui.Theme.mix(Ui.Theme.border, Ui.Theme.text, 0.14)
        opacity: 0.85
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: row.scaled(20)
        anchors.rightMargin: row.scaled(16)
        spacing: row.scaled(10)

        Text {
            Layout.preferredWidth: row.scaled(28)
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: row.resultData.icon || "󰂯"
            color: row.device.connected ? Ui.Theme.active : Ui.Theme.mutedText
            font.family: Ui.Theme.iconFontFamily
            font.pixelSize: Math.max(Ui.Theme.iconSize, row.scaled(Ui.Theme.fontSizeTitle))
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Math.max(1, row.scaled(2))

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignBottom
                text: row.resultData.title
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Math.max(Ui.Theme.fontSizeSmall, row.scaled(Ui.Theme.fontSizeLabel))
                font.weight: row.device.connected ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignTop
                text: row.resultData.subtitle
                color: Ui.Theme.subtleText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Math.max(10, row.scaled(Ui.Theme.fontSizeCaption))
                elide: Text.ElideRight
            }
        }

        Text {
            Layout.preferredWidth: row.scaled(18)
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: row.selected && row.detailsOpen ? "󰅁" : "󰅂"
            color: row.selected || chevronMouse.containsMouse ? Ui.Theme.accent : Ui.Theme.mutedText
            font.family: Ui.Theme.iconFontFamily
            font.pixelSize: Math.max(Ui.Theme.iconSizeSmall, row.scaled(Ui.Theme.iconSize))

            MouseArea {
                id: chevronMouse

                anchors.fill: parent
                anchors.margins: -row.scaled(Ui.Theme.spacingSm)
                cursorShape: Qt.PointingHandCursor
                onClicked: row.detailsToggled(row.index)
            }
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
