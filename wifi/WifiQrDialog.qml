import QtQuick
import QtQuick.Layouts
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

    FormField {
        width: parent.width
        visible: dialog.qr.password.length > 0
        label: qsTr("Password")
        icon: "key"
        accessibleName: qsTr("Wi-Fi password")
        TextField {
            Layout.fillWidth: true
            sensitive: true
            readOnly: true
            text: dialog.qr.password
        }
    }

    icon: "qr_code"
    actions: [
        {id: "copy", label: qsTr("Copy payload"), icon: "content_copy", presentation: {group: "toolbar"}},
        {id: "scan", label: qsTr("Scan another code"), icon: "qr_code_scanner", presentation: {group: "toolbar"}},
        {id: "close", label: qsTr("Close"), icon: "close", presentation: {group: "primary"}}
    ]
    onActionTriggered: function(actionId) {
        if (actionId === "copy") qr.copyPayload();
        else if (actionId === "scan") qr.launchScanner(false);
        else closed();
    }
}
