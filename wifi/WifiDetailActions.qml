import QtQuick

Item {
    id: model

    required property var controller

    readonly property var actions: [
        { id: "connect", label: "Connect", hotkey: "C", enabled: controller.canConnectDetail(), toolbar: true, visible: !controller.isActive(controller.detailAp) && !controller.connectRunning, width: 112, tone: "active" },
        { id: "cancel-connect", label: "Cancel", hotkey: "C", enabled: controller.activeConnectRequestId.length > 0, toolbar: true, visible: controller.connectRunning, width: 112, tone: "danger" },
        { id: "disconnect", label: "Disconnect", hotkey: "D", enabled: controller.canDisconnectDetail(), toolbar: true, visible: controller.isActive(controller.detailAp) && !controller.connectRunning, width: 112, tone: "danger" },
        { id: "forget", label: controller.isActive(controller.detailAp) ? "Disconnect & forget" : "Forget", hotkey: "F", enabled: controller.canForgetProfile(), toolbar: true, visible: true, width: controller.isActive(controller.detailAp) ? 154 : 90, tone: "normal" },
        { id: "portal", label: "Sign in", hotkey: "I", enabled: controller.hasSelection, toolbar: true, visible: true, width: 90, tone: "normal" },
        { id: "share", label: "Share", hotkey: "S", enabled: controller.canShareSelected(), toolbar: true, visible: true, width: 90, tone: "normal" },
        { id: "autoconnect", label: "Auto-connect", hotkey: "A", enabled: controller.canToggleAutoconnectProfile(), setting: true, checked: controller.autoconnectEnabled(), subtitle: controller.profileFor(controller.detailAp) ? "Connect automatically when this network is in range" : "Connect once before autoconnect is available" },
        { id: "randomized-mac", label: "Randomise MAC address", hotkey: "R", enabled: controller.canSetMacRandomizationProfile(), setting: true, checked: controller.randomizedMacEnabled(), subtitle: controller.randomizedMacEnabled() ? "Use a stable private MAC for this network" : "Use this device's hardware MAC for this network" },
        { id: "send-hostname", label: "Send device name", hotkey: "N", enabled: controller.canSetSendHostnameProfile(), setting: true, checked: controller.sendHostnameEnabled(), subtitle: "Share this device's name with the network" }
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
