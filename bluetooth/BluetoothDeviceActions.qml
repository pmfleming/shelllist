import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section
    required property BluetoothController controller
    property bool confirmRemove
    readonly property bool editingName: renameInput.activeFocus
    Layout.fillWidth: true
    spacing: 10

    function localFilePath(url) {
        const value = url.toString();
        return value.indexOf("file://") === 0 ? decodeURIComponent(value.slice(7)) : value;
    }
    function cancelRemove() { confirmRemove = false; }

    Connections {
        target: section.controller
        function onSelectedResultChanged() {
            section.confirmRemove = false;
            renameInput.text = section.controller.selectedDevice.name || "";
        }
    }
    FileDialog {
        id: outgoingFileDialog
        title: "Send file over Bluetooth"
        fileMode: FileDialog.OpenFile
        onAccepted: section.controller.sendFile(section.localFilePath(selectedFile))
    }
    Text { text: "Device name"; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11 }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: Ui.Theme.cardRadius
        color: Ui.Theme.surfaceRaised
        border.color: renameInput.activeFocus ? Ui.Theme.accent : Ui.Theme.border
        TextInput {
            id: renameInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            text: section.controller.selectedDevice.name || ""
            maximumLength: 248
            verticalAlignment: TextInput.AlignVCenter
            color: Ui.Theme.text
            selectionColor: Ui.Theme.accent
            font.family: Ui.Theme.fontFamily
            font.pixelSize: 13
            clip: true
            onAccepted: section.controller.renameSelected(text)
        }
    }
    BluetoothActionButton {
        label: "Save device name"
        available: !!(section.controller.selectedDevice.capabilities && section.controller.selectedDevice.capabilities.can_rename)
            && renameInput.text.trim().length > 0
            && renameInput.text.trim() !== (section.controller.selectedDevice.name || "")
            && !section.controller.actionInFlight
        onClicked: section.controller.renameSelected(renameInput.text)
    }
    BluetoothActionButton {
        visible: !!section.controller.obexCapabilities.outgoing_object_push && !section.controller.canCancelTransfer
        label: "Send file"
        available: !!(section.controller.selectedDevice.capabilities && section.controller.selectedDevice.capabilities.can_send_file) && !section.controller.actionInFlight
        onClicked: outgoingFileDialog.open()
    }
    BluetoothActionButton {
        visible: section.controller.canCancelTransfer
        label: "Cancel " + ((section.controller.activeTransfer || ({})).file_name || "transfer")
        danger: true
        onClicked: section.controller.cancelActiveTransfer()
    }
    BluetoothActionButton { visible: !section.controller.canCancelOperation && !section.controller.canCancelTransfer; label: section.controller.selectedDevice.connected ? "Disconnect" : (section.controller.selectedDevice.paired ? "Connect" : "Pair"); available: section.controller.hasSelection && !section.controller.actionInFlight; onClicked: section.controller.primarySelected() }
    BluetoothActionButton { visible: section.controller.canCancelOperation; label: "Cancel operation"; danger: true; onClicked: section.controller.cancelActiveOperation() }
    BluetoothActionButton { label: (section.controller.selectedDevice.trusted ? "Disable" : "Enable") + " trust"; available: !!(section.controller.selectedDevice.capabilities && section.controller.selectedDevice.capabilities.can_trust); onClicked: section.controller.triggerAction("trusted") }
    BluetoothActionButton { visible: section.controller.selectedDevice.wake_allowed !== null && section.controller.selectedDevice.wake_allowed !== undefined; label: (section.controller.selectedDevice.wake_allowed ? "Disable" : "Enable") + " wake"; available: !!(section.controller.selectedDevice.capabilities && section.controller.selectedDevice.capabilities.can_wake); onClicked: section.controller.triggerAction("wake") }
    BluetoothActionButton { label: section.controller.selectedDevice.blocked ? "Unblock device" : "Block device"; danger: !section.controller.selectedDevice.blocked; available: !!(section.controller.selectedDevice.capabilities && section.controller.selectedDevice.capabilities.can_block); onClicked: section.controller.triggerAction("blocked") }
    BluetoothActionButton { visible: !section.confirmRemove; label: "Remove device"; danger: true; available: !!(section.controller.selectedDevice.capabilities && section.controller.selectedDevice.capabilities.can_remove); onClicked: section.confirmRemove = true }
    RowLayout {
        visible: section.confirmRemove
        Layout.fillWidth: true
        BluetoothActionButton { label: "Cancel"; onClicked: section.confirmRemove = false }
        BluetoothActionButton { label: "Remove"; danger: true; onClicked: { section.confirmRemove = false; section.controller.triggerAction("remove"); } }
    }
}
