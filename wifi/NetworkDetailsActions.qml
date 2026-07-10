import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: row

    required property var controller
    readonly property var ap: controller.detailAp
    readonly property bool apActive: controller.isActive(ap)

    width: parent ? parent.width : 0
    height: 46
    spacing: 8

    ActionButton {
        Layout.preferredWidth: 112
        label: row.controller.isConnecting(row.ap) ? "Connecting…" : (row.apActive ? "Disconnect" : "Connect")
        hotkey: row.apActive ? "D" : "C"
        backgroundColor: row.apActive ? Theme.danger : Theme.active
        borderColor: row.apActive ? Theme.danger : Theme.active
        labelColor: row.apActive ? Theme.dangerText : Theme.activeText
        enabled: row.controller.canUsePrimaryAction()
        onClicked: row.apActive ? row.controller.disconnectSelected() : row.controller.connectSelected()
    }

    ActionButton {
        Layout.preferredWidth: 90
        label: "Forget"
        hotkey: "F"
        enabled: row.controller.canForgetProfile()
        onClicked: row.controller.forgetSelected()
    }

    ActionButton {
        Layout.preferredWidth: 90
        label: "Sign in"
        hotkey: "I"
        onClicked: row.controller.openPortal()
    }

    ActionButton {
        Layout.preferredWidth: 90
        label: "Share"
        hotkey: "S"
        enabled: row.controller.canShareSelected()
        onClicked: row.controller.shareSelected()
    }

    Item { Layout.fillWidth: true }
}
