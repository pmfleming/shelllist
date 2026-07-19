import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: prompt

    required property var controller
    readonly property var request: controller.pairingPrompt || ({})
    readonly property string kind: request.kind || ""
    readonly property bool responseRequired: !!request.response_required
    readonly property bool inputRequired: kind === "pin-code" || kind === "passkey"
    readonly property bool inputValid: !inputRequired || (controller.pairingInput.length > 0 && (kind !== "passkey" || /^\d{1,6}$/.test(controller.pairingInput)))
    readonly property string deviceName: controller.selectedDevice && controller.selectedDevice.key === request.device_key ? controller.selectedDevice.name : "Bluetooth device"

    anchors.fill: parent
    visible: controller.pairingPromptOpen
    z: 100
    radius: Ui.Theme.windowRadius
    color: Ui.Theme.mix(Ui.Theme.window, "#000000", 0.12)
    border.color: Ui.Theme.strongBorder

    function heading() {
        if (kind === "confirmation") return "Confirm pairing code";
        if (kind === "authorization") return "Allow pairing?";
        if (kind === "service-authorization") return "Allow Bluetooth service?";
        if (kind === "pin-code") return "Enter PIN";
        if (kind === "passkey") return "Enter passkey";
        return "Complete pairing";
    }
    function detail() {
        if (kind === "display-pin" || kind === "display-passkey") return "Enter this code on " + deviceName;
        if (kind === "confirmation") return "Verify that this code matches " + deviceName;
        if (kind === "service-authorization") return deviceName + " is requesting service " + (request.service || "access");
        if (kind === "authorization") return deviceName + " wants to pair with this computer";
        return "Provide the value requested by " + deviceName;
    }

    Shortcut { sequence: "Escape"; enabled: prompt.visible && prompt.responseRequired; onActivated: prompt.controller.respondPairing(false) }
    Shortcut { sequence: "Enter"; enabled: prompt.visible && prompt.responseRequired && prompt.inputValid; onActivated: prompt.controller.respondPairing(true) }

    MouseArea { anchors.fill: parent }

    Rectangle {
        anchors.centerIn: parent
        width: 430
        implicitHeight: promptColumn.implicitHeight + 48
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.strongBorder

        ColumnLayout {
            id: promptColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 24
            spacing: 13

            Text {
                Layout.fillWidth: true
                text: prompt.heading()
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                Layout.fillWidth: true
                text: prompt.detail()
                color: Ui.Theme.subtleText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
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
                Component.onCompleted: if (prompt.visible) Qt.callLater(pairingInput.forceActiveFocus)
            }
            RowLayout {
                visible: prompt.responseRequired
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Ui.Theme.cardRadius
                    color: Ui.Theme.surfaceRaised
                    border.color: Ui.Theme.border
                    Text { anchors.centerIn: parent; text: "Reject"; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 13; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: prompt.controller.respondPairing(false) }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Ui.Theme.cardRadius
                    color: Ui.Theme.accent
                    opacity: prompt.inputValid ? 1 : 0.45
                    Text { anchors.centerIn: parent; text: "Confirm"; color: Ui.Theme.window; font.family: Ui.Theme.fontFamily; font.pixelSize: 13; font.bold: true }
                    MouseArea { anchors.fill: parent; enabled: prompt.inputValid; cursorShape: Qt.PointingHandCursor; onClicked: prompt.controller.respondPairing(true) }
                }
            }
            Text {
                visible: !prompt.responseRequired
                Layout.fillWidth: true
                text: "Waiting for the remote device…"
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    onVisibleChanged: if (visible && inputRequired) Qt.callLater(pairingInput.forceActiveFocus)
}
