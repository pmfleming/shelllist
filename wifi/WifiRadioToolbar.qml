import QtQuick
import QtQuick.Layouts
import Shelllist.Ui

RowLayout {
    id: toolbar

    required property WifiController controller
    spacing: Theme.spacingSm

    ActionButton {
        Layout.fillWidth: true
        label: !toolbar.controller.radios.wireless_available ? "No Wi-Fi adapter"
            : (!toolbar.controller.radios.wireless_hardware_enabled ? "Wi-Fi blocked"
            : (toolbar.controller.powered ? "Wi-Fi on" : "Wi-Fi off"))
        icon: "󰖩"
        enabled: toolbar.controller.radios.wireless_available
            && toolbar.controller.radios.wireless_hardware_enabled
            && !toolbar.controller.airplaneMode && !toolbar.controller.actionInFlight
        tone: toolbar.controller.powered ? "active" : "normal"
        onClicked: toolbar.controller.setPower()
    }

    ActionButton {
        Layout.fillWidth: true
        label: !toolbar.controller.radios.wwan_available ? "No mobile modem"
            : (!toolbar.controller.radios.wwan_hardware_enabled ? "Mobile blocked"
            : (toolbar.controller.wwanPowered ? "Mobile on" : "Mobile off"))
        icon: "󰢮"
        enabled: toolbar.controller.radios.wwan_available
            && toolbar.controller.radios.wwan_hardware_enabled
            && !toolbar.controller.airplaneMode && !toolbar.controller.actionInFlight
        tone: toolbar.controller.wwanPowered ? "active" : "normal"
        onClicked: toolbar.controller.setWwanPower()
    }

    ActionButton {
        Layout.fillWidth: true
        label: toolbar.controller.airplaneMode ? "Airplane on" : "Airplane off"
        icon: "󰀝"
        enabled: !toolbar.controller.actionInFlight
        tone: toolbar.controller.airplaneMode ? "warning" : "normal"
        onClicked: toolbar.controller.setAirplaneMode()
    }

    ActionButton {
        Layout.preferredWidth: 108
        label: "Scan QR"
        icon: "󰐲"
        enabled: !toolbar.controller.actionInFlight
        onClicked: toolbar.controller.launchQrScanner()
    }
}
