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
    property alias scaleValues: slider.scaleValues
    property alias minimumValue: slider.minimumValue
    property alias maximumValue: slider.maximumValue
    property alias peerValue: slider.peerValue
    property string accessibleName: label
    property string scaleDescription: ""
    property string scaleStartText: ""
    property string scaleEndText: ""
    signal editRejected
    property string valueText: String(value)
    readonly property real labelWidth: labelColumnWidth
    property real valueWidth: 76
    readonly property alias inputActiveFocus: slider.activeFocus
    Accessible.name: label
    Accessible.description: valueText
    function focusInput(): void { slider.forceActiveFocus(); }
    signal edited(bool dragging)
    signal editingFinished

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 0
        ValueSlider {
            id: slider
            objectName: "labeledValueSliderInput"
            Layout.fillWidth: true
            Accessible.name: row.accessibleName
            Accessible.description: [row.valueText, row.scaleDescription, qsTr("Allowed values: %1 to %2").arg(row.minimumValue).arg(row.maximumValue)].join(". ")
            onEditRejected: row.editRejected()
            onEdited: row.edited(pressed)
            onEditingFinished: row.editingFinished()
        }
        RowLayout {
            visible: row.scaleStartText.length > 0 || row.scaleEndText.length > 0
            Layout.fillWidth: true
            ThemeText {
                text: row.scaleStartText
                font.pixelSize: Theme.metadataSize
                color: Theme.mutedText
                Accessible.ignored: true
            }
            Item { Layout.fillWidth: true }
            ThemeText {
                text: row.scaleEndText
                font.pixelSize: Theme.metadataSize
                color: Theme.mutedText
                Accessible.ignored: true
            }
        }
    }
    ThemeText {
        Layout.preferredWidth: row.valueWidth
        text: row.valueText
        font.pixelSize: Theme.formValueSize
        horizontalAlignment: Text.AlignRight
    }
}
