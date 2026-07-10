import QtQuick
import "."

DetailCard {
    id: card

    required property var controller
    readonly property var ap: controller.detailAp

    height: 174
    title: "Profile settings"

    Column {
        anchors.fill: parent
        spacing: 8

        ProfileToggleRow {
            title: "Auto-connect"
            hotkey: "A"
            subtitle: card.controller.profileFor(card.ap) ? "Connect automatically when this network is in range" : "Connect once before autoconnect is available"
            checked: card.controller.autoconnectEnabled()
            interactive: card.controller.canToggleAutoconnectProfile()
            onClicked: card.controller.toggleAutoconnectSelected()
        }

        ProfileToggleRow {
            title: "Randomise MAC address"
            hotkey: "R"
            subtitle: card.controller.randomizedMacEnabled() ? "Use a stable private MAC for this network" : "Use this device's hardware MAC for this network"
            checked: card.controller.randomizedMacEnabled()
            interactive: card.controller.canSetMacRandomizationProfile()
            onClicked: card.controller.toggleRandomizedMacSelected()
        }

        ProfileToggleRow {
            title: "Send device name"
            hotkey: "N"
            subtitle: "Share this device's name with the network"
            checked: card.controller.sendHostnameEnabled()
            interactive: card.controller.canSetSendHostnameProfile()
            onClicked: card.controller.toggleSendHostnameSelected()
        }
    }
}
