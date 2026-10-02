import QtQuick
import QtQuick.Layouts
import Shelllist.Ui

GridLayout {
    id: row

    required property string label
    property alias value: control.value
    property alias options: control.options

    signal selected(string value)

    width: parent.width
    columns: width >= 480 ? 2 : 1
    columnSpacing: Theme.spacingMd
    rowSpacing: Theme.spacingSm

    FieldLabel {
        Layout.preferredWidth: 150
        Layout.fillWidth: row.columns === 1
        text: row.label
    }

    SegmentedControl {
        id: control
        objectName: row.objectName
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        onSelected: function (value) {
            row.selected(value);
        }
    }
}
