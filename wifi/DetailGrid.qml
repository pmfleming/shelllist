import QtQuick
import "."

Grid {
    property var entries: []
    width: parent ? parent.width : 0; columns: 2; columnSpacing: 46; rowSpacing: 14
    Repeater {
        model: entries
        DetailField { label: modelData.label; value: modelData.value; valueColor: modelData.valueColor || Theme.text; valueBold: !!modelData.valueBold; valueWidth: modelData.valueWidth || width }
    }
}
