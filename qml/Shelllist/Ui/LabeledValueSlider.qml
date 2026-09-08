import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row

    required property string label
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property string valueText: String(value)
    readonly property alias inputActiveFocus: slider.activeFocus

    signal edited(bool dragging)
    signal editingFinished

    spacing: Theme.spacingMd

    FieldLabel {
        Layout.preferredWidth: 150
        text: row.label
    }
    ValueSlider {
        id: slider
        objectName: "labeledValueSliderInput"
        Layout.fillWidth: true
        Accessible.name: row.label
        Accessible.description: row.valueText
        onEdited: row.edited(pressed)
        onEditingFinished: row.editingFinished()
    }
    ThemeText {
        Layout.preferredWidth: 76
        text: row.valueText
        horizontalAlignment: Text.AlignRight
    }
}
