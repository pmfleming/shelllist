import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: control

    required property BluetoothController controller
    required property string mode
    property alias value: timeout.value
    readonly property alias inputActiveFocus: timeout.inputActiveFocus
    readonly property bool discoverable: mode === "discoverable"
    readonly property var adapter: controller.selectedAdapter

    signal edited(bool dragging)
    signal editingFinished

    spacing: Ui.Theme.spacingSm

    Ui.ToggleRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        title: control.discoverable ? "Discoverable" : "Incoming pairing"
        subtitle: control.discoverable
            ? "Allow nearby devices to find this computer"
            : "Allow new devices to request pairing"
        checked: !!control.adapter[control.mode]
        interactive: !!control.adapter.key && !control.controller.globalRequestInFlight
            && (!control.discoverable || control.adapter.powered)
        onClicked: control.controller.adapterOperation("set-" + control.mode,
            ({ [control.mode]: !control.adapter[control.mode] }))
    }

    Ui.LabeledValueSlider {
        id: timeout
        Layout.fillWidth: true
        label: (control.discoverable ? "Discoverable" : "Pairable") + " timeout"
        from: 0
        to: 3600
        stepSize: 30
        valueText: Ui.Format.duration(value)
        enabled: !control.controller.globalRequestInFlight && !!control.adapter.key
        onEdited: function (dragging) { control.edited(dragging); }
        onEditingFinished: control.editingFinished()
    }
}
