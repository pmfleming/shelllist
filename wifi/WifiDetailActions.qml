import QtQuick

Item {
    required property WifiController controller

    readonly property var actions: [
        { id: "connect", label: "Connect", icon: "󰖩", hotkey: "C", enabled: controller.canConnectDetail(), toolbar: true, primary: true, visible: !controller.isActive(controller.detailAp) && !controller.connectRunning, width: 152, tone: "active" },
        { id: "cancel-connect", label: "Cancel", icon: "󰜺", hotkey: "C", enabled: controller.activeConnectRequestId.length > 0, toolbar: true, primary: true, visible: controller.connectRunning, width: 152, tone: "danger" },
        { id: "disconnect", label: "Disconnect", icon: "󰤭", hotkey: "D", enabled: controller.canDisconnectDetail(), toolbar: true, primary: true, visible: controller.isActive(controller.detailAp) && !controller.connectRunning, width: 152, tone: "danger" },
        { id: "forget", label: "Forget", icon: "󰆴", hotkey: "F", enabled: controller.canForgetProfile(), toolbar: true, primary: false, visible: true, width: 92, tone: "normal" },
        { id: "portal", label: "Sign in", icon: "󰏌", hotkey: "I", enabled: controller.hasSelection, toolbar: true, primary: false, visible: true, width: 100, tone: "normal" },
        { id: "share", label: "Share", icon: "󰒖", hotkey: "S", enabled: controller.canShareSelected(), toolbar: true, primary: false, visible: true, width: 92, tone: "normal" },
        { id: "autoconnect", label: "Auto-connect", hotkey: "A", enabled: controller.canToggleAutoconnectProfile(), setting: true, checked: controller.autoconnectEnabled() },
        { id: "randomized-mac", label: "Randomize MAC address", hotkey: "R", enabled: controller.canSetMacRandomizationProfile(), setting: true, checked: controller.randomizedMacEnabled() },
        { id: "send-hostname", label: "Send device name", hotkey: "N", enabled: controller.canSetSendHostnameProfile(), setting: true, checked: controller.sendHostnameEnabled() }
    ]

    function trigger(id) {
        const handlers = {
            connect: controller.connectSelected,
            "cancel-connect": controller.cancelConnection,
            disconnect: controller.disconnectSelected,
            forget: controller.forgetSelected,
            portal: controller.openPortal,
            share: controller.shareSelected,
            autoconnect: controller.toggleAutoconnectSelected,
            "randomized-mac": controller.toggleRandomizedMacSelected,
            "send-hostname": controller.toggleSendHostnameSelected
        };
        if (handlers[id])
            handlers[id]();
    }
}
