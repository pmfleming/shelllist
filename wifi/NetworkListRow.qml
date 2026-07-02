import QtQuick
import "."

Rectangle {
    id: row

    required property int index
    required property var modelData
    property bool active: false
    property string name: modelData.ssid || "<hidden>"
    property int selectedIndex: 0
    property bool detailsOpen: false
    property bool connecting: false
    property int progressTick: 0
    readonly property var spinnerFrames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    signal picked(int rowIndex)
    signal connectRequested
    signal detailsToggled(int rowIndex)

    width: ListView.view.width
    height: 43
    radius: Theme.controlRadius
    color: index === selectedIndex ? Theme.selected : "transparent"
    border.color: index === selectedIndex ? Theme.strongBorder : "transparent"
    border.width: index === selectedIndex ? 1 : 0

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
            text: row.connecting ? row.spinnerFrames[row.progressTick % row.spinnerFrames.length] : (row.active ? "●" : (row.modelData.security === "--" ? "Open" : "🔒"))
            color: row.connecting ? Theme.accent : (row.active ? Theme.active : (row.modelData.security === "--" ? Theme.warning : Theme.mutedText))
            font.pixelSize: row.modelData.security === "--" && !row.active && !row.connecting ? 8 : 13
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
            color: row.index === row.selectedIndex ? Theme.accent : Theme.mutedText
            font.pixelSize: 25

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    row.picked(row.index);
                    row.detailsToggled(row.index);
                }
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
