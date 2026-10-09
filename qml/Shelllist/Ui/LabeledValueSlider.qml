import QtQuick
import QtQuick.Layouts

FieldRow {
    id: row
    required label
    readonly property alias editSession: slider.editSession
    property alias livePreview: slider.livePreview
    property alias value: slider.value
    property alias browseFocused: slider.browseFocused
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property string valueText: String(value)
    readonly property real labelWidth: labelColumnWidth
    property real valueWidth: 76
    readonly property alias inputActiveFocus: slider.activeFocus
    Accessible.name: label
    Accessible.description: valueText
    function focusInput(): void { slider.forceActiveFocus(); }
    signal edited(bool dragging)
    signal editingFinished

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
        Layout.preferredWidth: row.valueWidth
        text: row.valueText
        font.pixelSize: Theme.formValueSize
        horizontalAlignment: Text.AlignRight
    }
}
