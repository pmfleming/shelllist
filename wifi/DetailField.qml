import QtQuick
import "."

Column {
    id: field

    property string label: ""
    property string value: "—"
    property color valueColor: Theme.text
    property bool valueBold: false
    property int valueWidth: width

    width: 245
    spacing: 3

    Text {
        text: field.label
        color: Theme.mutedText
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
