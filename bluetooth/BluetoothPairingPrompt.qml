import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.PromptDialog {
    id: prompt

    required property BluetoothController controller
    readonly property var request: controller.pairingPrompt || ({})
    readonly property string kind: request.kind || ""
    readonly property bool responseRequired: !!request.response_required
    readonly property bool inputRequired: kind === "pin-code" || kind === "passkey"
    readonly property bool valueValid: !inputRequired || (controller.pairingInput.length > 0 && (kind !== "passkey" || /^\d{1,6}$/.test(controller.pairingInput)))
    readonly property string deviceName: request.device_key && controller.selectedDevice && controller.selectedDevice.key === request.device_key
        ? (controller.selectedDevice.name || "Bluetooth device") : "Bluetooth device"
    readonly property var headings: ({
        "confirmation": "Confirm pairing code",
        "authorization": "Allow pairing?",
        "service-authorization": "Allow Bluetooth service?",
        "pin-code": "Enter PIN",
        "passkey": "Enter passkey"
    })

    visible: controller.pairingPromptOpen
    z: 100
    title: headings[kind] || "Complete pairing"
    detail: detailText()
    inputVisible: inputRequired
    inputText: controller.pairingInput
    password: true
    inputValid: valueValid
    inputMaximumLength: kind === "passkey" ? 6 : 16
    inputMethodHints: kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
    inputHorizontalAlignment: TextInput.AlignHCenter
    actionsVisible: responseRequired
    rejectLabel: "Reject"
    acceptLabel: "Confirm"
    acceptEnabled: valueValid
    escapeEnabled: responseRequired
    enterEnabled: responseRequired
    instruction: responseRequired ? "Enter confirm   •   Esc reject" : "Waiting for the remote device…"
    onInputEdited: function (text) { controller.pairingInput = text; }
    onAccepted: controller.respondPairing(true)
    onCancelled: controller.respondPairing(false)

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
        font.weight: Ui.Theme.fontWeightBold
        horizontalAlignment: Text.AlignHCenter
    }
    Text {
        visible: prompt.kind === "display-passkey" && Number(prompt.request.entered || 0) > 0
        Layout.fillWidth: true
        text: Number(prompt.request.entered || 0) + " of 6 digits entered"
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        horizontalAlignment: Text.AlignHCenter
    }
}
