pragma ComponentBehavior: Bound

import QtQuick

Grid {
    id: grid

    property var entries: []
    readonly property int rowCount: Math.max(1, Math.ceil(entries.length / 2))
    readonly property real fieldWidth: Math.max(160, (width - columnSpacing) / 2)
    readonly property real fieldHeight: {
        const firstField = fieldRepeater.itemAt(0);
        return firstField ? firstField.implicitHeight : 0;
    }

    width: parent ? parent.width : 0
    height: parent ? parent.height : implicitHeight
    columns: 2
    columnSpacing: Math.max(24, Math.min(48, width * 0.08))
    rowSpacing: rowCount > 1
        ? Math.max(Theme.spacingXs, Math.min(24, (height - rowCount * fieldHeight) / (rowCount - 1)))
        : 0

    Repeater {
        id: fieldRepeater

        model: grid.entries

        delegate: DetailField {
            required property var modelData

            width: grid.fieldWidth
            label: modelData.label
            value: modelData.value
            valueColor: modelData.valueColor || Theme.text
            valueBold: !!modelData.valueBold
            valueWidth: modelData.valueWidth || width
        }
    }
}
