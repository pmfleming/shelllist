import QtQuick
import QtQuick.Layouts
import Shelllist.Ui

// Domain adapter only: layout belongs to the same FormField as other panels.
FormField {
    id: row
    required label
    property alias value: control.value
    property alias options: control.options
    signal selected(string value)
    width: parent.width

    SegmentedControl {
        id: control
        Accessible.name: row.label
        objectName: row.objectName
        Layout.fillWidth: true
        onSelected: function (value) { row.selected(value); }
    }
}
