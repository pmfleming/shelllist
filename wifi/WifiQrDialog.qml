import QtQuick
import QtQuick.Layouts
import Shelllist.Ui

ModalFrame {
    id: dialog

    required property WifiQrController qr
    signal closed

    title: "Share " + qr.networkName
    detail: "Scan this code with another device to join the Wi-Fi network."
    maximumCardWidth: 520

    Keys.onEscapePressed: dialog.closed()

    Rectangle {
        width: Math.min(parent.width, 360)
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

    RowLayout {
        width: parent.width
        spacing: Theme.spacingMd

        ActionButton {
            Layout.fillWidth: true
            label: "Copy payload"
            onClicked: dialog.qr.copyPayload()
        }

        ActionButton {
            Layout.fillWidth: true
            label: "Scan another code"
            onClicked: dialog.qr.launchScanner()
        }

        ActionButton {
            Layout.fillWidth: true
            label: "Close"
            tone: "accent"
            onClicked: dialog.closed()
        }
    }
}
