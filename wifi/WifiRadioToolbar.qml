import QtQuick
import QtQuick.Layouts
import Shelllist.Ui

RowLayout {
    id: toolbar

    required property WifiController controller
    spacing: Theme.spacingSm

    // Mobile-modem state and setWwanPower() intentionally remain in the controller/backend.
    // A dedicated mobile-broadband surface can expose them once modem workflows are designed.
    ActionButton {
        Layout.fillWidth: true
        label: !toolbar.controller.radios.wireless_available ? "No Wi-Fi adapter"
            : (!toolbar.controller.radios.wireless_hardware_enabled ? "Wi-Fi blocked"
            : (toolbar.controller.powered ? "Wi-Fi on" : "Wi-Fi off"))
        icon: "󰖩"
        enabled: toolbar.controller.radios.wireless_available
            && toolbar.controller.radios.wireless_hardware_enabled
            && !toolbar.controller.actionInFlight
        tone: toolbar.controller.powered ? "active" : "normal"
        onClicked: toolbar.controller.setPower()
    }
}
