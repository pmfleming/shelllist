import QtQuick
import "."

Grid {
    id: grid

    property var entries: []
    width: parent ? parent.width : 0; columns: 2; columnSpacing: 46; rowSpacing: 14
    Repeater {
        model: grid.entries
        DetailField {
            required property var modelData
            label: modelData.label
            value: modelData.value
            valueColor: modelData.valueColor || Theme.text
            valueBold: !!modelData.valueBold
            valueWidth: modelData.valueWidth || width
        }
    }
}
