import QtQuick
import QtQuick.Layouts

Item {
    id: row

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    required property string label
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property string valueText: String(value)
    property real labelWidth: 150
    property real valueWidth: 76
    readonly property alias inputActiveFocus: slider.activeFocus

    Accessible.name: label
    Accessible.description: valueText

    function focusInput(): void {
        slider.forceActiveFocus();
    }

    signal edited(bool dragging)
    signal editingFinished

    RowLayout {
        id: content
        anchors.fill: parent
        spacing: Theme.spacingMd

        FieldLabel {
            Layout.preferredWidth: row.labelWidth
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
            Layout.preferredWidth: row.valueWidth
            text: row.valueText
            horizontalAlignment: Text.AlignRight
        }
    }
}
