import QtQuick
import Shelllist.Ui
import "process"

ModalFrame {
    id: dialog

    required property WifiQrService qr
    signal closed

    title: "Share " + qr.networkName
    detail: "Scan this code with another device to join the Wi-Fi network."
    maximumCardWidth: 520

    Keys.onEscapePressed: dialog.closed()

    Rectangle {
        width: Math.min(parent.width, dialog.height < 700 ? 280 : 360)
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Theme.controlRadius
        color: "white"

        Image {
            anchors.fill: parent
            anchors.margins: Theme.spacingMd
            source: dialog.qr.imageSource
            fillMode: Image.PreserveAspectFit
            cache: false
            visible: source.toString().length > 0
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.spacingLg
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: dialog.qr.error.length > 0 ? dialog.qr.error : "Rendering QR code…"
            color: dialog.qr.error.length > 0 ? Theme.danger : Theme.mutedText
            visible: dialog.qr.imageSource.length === 0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXs
        visible: dialog.qr.password.length > 0

        FieldLabel { width: parent.width; height: 16; text: "Wi-Fi password" }
        TextField {
            width: parent.width
            height: Theme.controlHeight
            readOnly: true
            text: dialog.qr.password
        }
    }

    ActionToolbar {
        width: parent.width
        height: Theme.controlHeight
        fillActions: true
        actions: [{
            id: "copy", label: "Copy payload"
        }, {
            id: "scan", label: "Scan another code"
        }, {
            id: "close", label: "Close", presentation: { tone: "accent" }
        }]
        onTriggered: function (actionId) {
            if (actionId === "copy") dialog.qr.copyPayload();
            else if (actionId === "scan") dialog.qr.launchScanner(false);
            else dialog.closed();
        }
    }
}
