import QtQuick

Column {
    id: field

    property string label: ""
    property string value: "—"
    property color valueColor: "#cbd5e1"
    property bool valueBold: false
    property int valueWidth: width

    width: 245
    spacing: 3

    Text {
        text: field.label
        color: "#94a3b8"
        font.pixelSize: 13
    }

    Text {
        width: field.valueWidth
        text: field.value
        color: field.valueColor
        font.pixelSize: 14
        font.bold: field.valueBold
        elide: Text.ElideRight
    }
}
