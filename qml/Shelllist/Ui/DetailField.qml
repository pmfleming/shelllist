import QtQuick

Column {
    id: field

    property string label: ""
    property string value: "—"
    property color valueColor: Theme.text
    property bool valueBold: false
    property int valueWidth: width

    width: 245
    spacing: Theme.spacingXs

    Text {
        text: field.label
        color: Theme.mutedText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeBody
    }

    Text {
        width: field.valueWidth
        text: field.value
        color: field.valueColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        font.weight: field.valueBold ? Theme.fontWeightBold : Theme.fontWeightRegular
        elide: Text.ElideRight
    }
}
