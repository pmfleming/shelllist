import QtQuick

Rectangle {
    id: row

    required property int index
    required property var modelData
    property int selectedIndex: 0

    signal picked(int rowIndex)
    signal runRequested(var option)

    width: ListView.view.width
    height: 58
    radius: 8
    color: index === selectedIndex ? "#92400e" : "transparent"
    border.color: modelData.destructive ? "#7f1d1d" : "transparent"
    border.width: modelData.destructive ? 1 : 0
    opacity: modelData.enabled ? 1.0 : 0.55

    Column {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: row.modelData.label
            color: row.modelData.destructive ? "#fecaca" : "#e5e7eb"
            font.pixelSize: 16
            font.bold: row.modelData.enabled
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: row.modelData.detail || ""
            color: "#94a3b8"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: row.picked(row.index)
        onDoubleClicked: row.runRequested(row.modelData)
    }
}
