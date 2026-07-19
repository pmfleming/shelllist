import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: pane

    required property BluetoothController controller
    property alias confirmRemove: actions.confirmRemove
    readonly property alias editingName: actions.editingName

    visible: controller.detailsOpen
    Layout.preferredWidth: 348
    Layout.fillHeight: true
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border

    function cancelRemove() { actions.cancelRemove(); }

    Flickable {
        anchors.fill: parent
        anchors.margins: 18
        contentWidth: width
        contentHeight: detailColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: detailColumn
            width: parent.width
            spacing: 10

            BluetoothDeviceOverview { controller: pane.controller }
            BluetoothDeviceActions { id: actions; controller: pane.controller }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.border }
            Text { text: "Technical details"; color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 14; font.bold: true }
            BluetoothDetailValue { label: "Address"; value: pane.controller.selectedDevice.address || "" }
            BluetoothDetailValue { label: "Address type"; value: pane.controller.selectedDevice.address_type || "" }
            BluetoothDetailValue { label: "Adapter"; value: (pane.controller.selectedAdapter.alias || pane.controller.selectedAdapter.name || "") + " · " + (pane.controller.selectedAdapter.address || "") }
            BluetoothDetailValue { label: "RSSI"; value: pane.controller.selectedDevice.rssi === null || pane.controller.selectedDevice.rssi === undefined ? "Unavailable" : pane.controller.selectedDevice.rssi + " dBm" }
            BluetoothDetailValue { label: "Last seen"; value: pane.controller.selectedDevice.last_seen_ms ? new Date(pane.controller.selectedDevice.last_seen_ms).toLocaleString() : "Not observed this session" }
            BluetoothDetailValue { label: "Modalias"; value: pane.controller.selectedDevice.modalias || "" }
            BluetoothDetailValue { label: "UUIDs"; value: (pane.controller.selectedDevice.uuids || []).join("\n") }
            BluetoothAdapterSettings { controller: pane.controller }
        }
    }
}
