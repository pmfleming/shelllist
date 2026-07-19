import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

BluetoothPromptShell {
    id: prompt

    required property BluetoothController controller
    readonly property var request: controller.pairingPrompt || ({})
    readonly property string kind: request.kind || ""
    readonly property bool responseRequired: !!request.response_required
    readonly property bool inputRequired: kind === "pin-code" || kind === "passkey"
    readonly property bool inputValid: !inputRequired || (controller.pairingInput.length > 0 && (kind !== "passkey" || /^\d{1,6}$/.test(controller.pairingInput)))
    readonly property string deviceName: request.device_key && controller.selectedDevice && controller.selectedDevice.key === request.device_key ? (controller.selectedDevice.name || "Bluetooth device") : "Bluetooth device"
    readonly property var headings: ({
        "confirmation": "Confirm pairing code",
        "authorization": "Allow pairing?",
        "service-authorization": "Allow Bluetooth service?",
        "pin-code": "Enter PIN",
        "passkey": "Enter passkey"
    })

    visible: controller.pairingPromptOpen
    z: 100
    heading: headings[kind] || "Complete pairing"
    detail: detailText()
    actionsVisible: responseRequired
    acceptEnabled: inputValid
    footer: responseRequired ? "" : "Waiting for the remote device…"
    onAccepted: controller.respondPairing(true)
    onRejected: controller.respondPairing(false)

    function detailText() {
        if (kind === "display-pin" || kind === "display-passkey")
            return "Enter this code on " + deviceName;
        if (kind === "confirmation")
            return "Verify that this code matches " + deviceName;
        if (kind === "service-authorization")
            return deviceName + " is requesting service " + (request.service || "access");
        if (kind === "authorization")
            return deviceName + " wants to pair with this computer";
        return "Provide the value requested by " + deviceName;
    }

    Text {
        visible: !prompt.inputRequired && (prompt.request.value || "").length > 0
        Layout.fillWidth: true
        text: prompt.request.value || ""
        color: Ui.Theme.accent
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 34
        font.letterSpacing: 5
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
    }
    Text {
        visible: prompt.kind === "display-passkey" && Number(prompt.request.entered || 0) > 0
        Layout.fillWidth: true
        text: Number(prompt.request.entered || 0) + " of 6 digits entered"
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }
    Rectangle {
        visible: prompt.inputRequired
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        radius: Ui.Theme.cardRadius
        color: Ui.Theme.surfaceRaised
        border.color: pairingInput.activeFocus ? Ui.Theme.accent : Ui.Theme.border
        TextInput {
            id: pairingInput
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            text: prompt.controller.pairingInput
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: 18
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            maximumLength: prompt.kind === "passkey" ? 6 : 16
            inputMethodHints: prompt.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
            onTextEdited: prompt.controller.pairingInput = text
        }
    }

    onVisibleChanged: if (visible && inputRequired) Qt.callLater(pairingInput.forceActiveFocus)
}
