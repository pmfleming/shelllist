import QtQuick

Rectangle {
    id: row

    required property int index
    required property var modelData
    property bool active: false
    property string name: modelData.ssid || "<hidden>"
    property int selectedIndex: 0

    signal picked(int rowIndex)
    signal connectRequested

    width: ListView.view.width
    height: 43
    radius: 8
    color: index === selectedIndex ? "#15335f" : "transparent"
    border.color: index === selectedIndex ? "#3b82f6" : "transparent"
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
            color: "#bfdbfe"
            font.pixelSize: 14
        }

        Text {
            width: 22
            anchors.verticalCenter: parent.verticalCenter
            text: "▂▄▆"
            color: row.active ? "#38bdf8" : "#94a3b8"
            font.pixelSize: 13
        }

        Text {
            width: 16
            anchors.verticalCenter: parent.verticalCenter
            text: row.active ? "●" : (row.modelData.security === "--" ? "Open" : "🔒")
            color: row.active ? "#22c55e" : (row.modelData.security === "--" ? "#fbbf24" : "#94a3b8")
            font.pixelSize: row.modelData.security === "--" && !row.active ? 8 : 13
        }

        Text {
            width: parent.width - 122
            anchors.verticalCenter: parent.verticalCenter
            text: row.name
            color: "#d1d5db"
            font.pixelSize: 15
            font.bold: row.active
            elide: Text.ElideRight
        }

        Text {
            width: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: "#94a3b8"
            font.pixelSize: 25
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: row.picked(row.index)
        onDoubleClicked: row.connectRequested()
    }
}
