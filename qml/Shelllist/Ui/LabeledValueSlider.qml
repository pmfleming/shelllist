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
        Layout.fillWidth: true
        onEdited: row.edited(pressed)
        onPressedChanged: if (!pressed) row.editingFinished()
    }
    Text {
        Layout.preferredWidth: 76
        text: row.valueText
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeBody
        horizontalAlignment: Text.AlignRight
    }
}
