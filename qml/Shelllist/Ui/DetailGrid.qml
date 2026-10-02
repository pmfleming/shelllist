pragma ComponentBehavior: Bound

import QtQuick

Grid {
    id: grid

    property var entries: []
    readonly property real fieldWidth: Math.max(0, (width - columnSpacing * (columns - 1)) / columns)

    width: parent ? parent.width : 0
    columns: width >= 320 + columnSpacing ? 2 : 1
    columnSpacing: Math.max(24, Math.min(48, width * 0.08))
    rowSpacing: Theme.spacingMd

    Repeater {

        model: grid.entries

        delegate: DetailField {
            required property var modelData

            width: grid.fieldWidth
            label: modelData.label
            value: modelData.value
            valueColor: modelData.valueColor || Theme.text
            valueBold: !!modelData.valueBold
            valueWidth: Math.min(width, modelData.valueWidth || width)
        }
    }
}
