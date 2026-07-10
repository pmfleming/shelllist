import QtQuick
import "."

Rectangle {
    id: row

    required property int index
    required property var modelData
    property bool active: false
    property string name: ""
    property int selectedIndex: 0
    property bool detailsOpen: false
    property bool connecting: false
    property int progressTick: 0
    readonly property bool selected: index === selectedIndex
    readonly property bool openNetwork: modelData.security === "--"
    readonly property var spinnerFrames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    signal picked(int rowIndex)
    signal connectRequested
    signal detailsToggled(int rowIndex)

    width: ListView.view.width
    height: 43
    radius: Theme.controlRadius
    color: selected ? Theme.selected : "transparent"
    border.color: selected ? Theme.strongBorder : "transparent"
    border.width: selected ? 1 : 0

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            width: 42
            anchors.verticalCenter: parent.verticalCenter
            text: (row.modelData.strength || 0) + "%"
            color: Theme.accent
            font.pixelSize: 14
        }

        Text {
            width: 22
            anchors.verticalCenter: parent.verticalCenter
            text: "▂▄▆"
            color: row.active ? Theme.accent : Theme.mutedText
            font.pixelSize: 13
        }

        Text {
            width: 16
            anchors.verticalCenter: parent.verticalCenter
            text: row.connecting ? row.spinnerFrames[row.progressTick % row.spinnerFrames.length] : (row.active ? "●" : (row.openNetwork ? "Open" : "🔒"))
            color: row.connecting ? Theme.accent : (row.active ? Theme.active : (row.openNetwork ? Theme.warning : Theme.mutedText))
            font.pixelSize: row.openNetwork && !row.active && !row.connecting ? 8 : 13
        }

        Text {
            width: parent.width - 144
            anchors.verticalCenter: parent.verticalCenter
            text: row.connecting ? row.name + " — connecting…" : row.name
            color: row.connecting ? Theme.accent : Theme.text
            font.pixelSize: 15
            font.bold: row.active || row.connecting
            elide: Text.ElideRight
        }

        Text {
            width: 24
            anchors.verticalCenter: parent.verticalCenter
            text: row.detailsOpen ? "‹" : "›"
            color: row.selected ? Theme.accent : Theme.mutedText
            font.pixelSize: 25

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: row.detailsToggled(row.index)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: 36
        onClicked: row.picked(row.index)
        onDoubleClicked: row.connectRequested()
    }
}
