import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

BluetoothPromptShell {
    id: prompt

    required property BluetoothController controller
    readonly property var request: controller.incomingTransferPrompt || ({})

    visible: controller.incomingTransferPromptOpen
    z: 110
    heading: "Accept Bluetooth file?"
    detail: (request.device_name || "A paired Bluetooth device") + " wants to send:"
    acceptLabel: "Accept"
    footer: "Enter: accept   Esc: reject"
    onAccepted: controller.respondIncomingTransfer(true)
    onRejected: controller.respondIncomingTransfer(false)

    function sizeLabel() {
        const size = Number(request.size || 0);
        if (size <= 0) return "Size unavailable";
        if (size < 1024) return size + " B";
        if (size < 1024 * 1024) return (size / 1024).toFixed(1) + " KiB";
        if (size < 1024 * 1024 * 1024) return (size / (1024 * 1024)).toFixed(1) + " MiB";
        return (size / (1024 * 1024 * 1024)).toFixed(1) + " GiB";
    }

    Text {
        Layout.fillWidth: true
        text: prompt.request.file_name || "Unnamed file"
        color: Ui.Theme.accent
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 17
        font.bold: true
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignHCenter
    }
    Text {
        Layout.fillWidth: true
        text: prompt.sizeLabel() + (prompt.request.media_type ? " · " + prompt.request.media_type : "") + "\nAccepted files are saved in Downloads."
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 11
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}
