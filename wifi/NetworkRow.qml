import QtQuick

Rectangle {
    id: row

    required property int index
    required property var modelData
    property var networkName
    property int selectedIndex: 0

    signal picked(int rowIndex, bool openOptions)
    signal connectRequested()

    function securityLabel(security) {
        return security === "--" ? "open" : (security || "");
    }

    width: ListView.view.width
    height: 42
    radius: 8
    color: index === selectedIndex ? "#2563eb" : "transparent"

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Text {
            width: 24
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.active ? "●" : " "
            color: row.modelData.active ? "#22c55e" : "#94a3b8"
            font.pixelSize: 18
        }

        Text {
            width: 54
            anchors.verticalCenter: parent.verticalCenter
            text: (row.modelData.strength || 0) + "%"
            color: "#dbeafe"
            horizontalAlignment: Text.AlignRight
            font.pixelSize: 17
        }

        Text {
            width: 48
            anchors.verticalCenter: parent.verticalCenter
            text: row.securityLabel(row.modelData.security)
            color: row.modelData.security === "--" ? "#fbbf24" : "#cbd5e1"
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Text {
            width: parent.width - 160
            anchors.verticalCenter: parent.verticalCenter
            text: row.networkName ? row.networkName(row.modelData) : (row.modelData.ssid || "<hidden>")
            color: "#f8fafc"
            font.pixelSize: 18
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) { row.picked(row.index, mouse.button === Qt.RightButton); }
        onDoubleClicked: row.connectRequested()
    }
}
