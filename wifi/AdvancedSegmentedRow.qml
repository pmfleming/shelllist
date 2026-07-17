import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: row

    property string label
    property alias value: control.value
    property alias options: control.options

    signal selected(string value)

    width: parent.width
    height: 38
    spacing: 12

    AdvancedFieldLabel {
        Layout.preferredWidth: 150
        Layout.fillHeight: true
        text: row.label
    }

    SegmentedControl {
        id: control
        Layout.fillWidth: true
        Layout.fillHeight: true
        onSelected: function (value) { row.selected(value); }
    }
}
