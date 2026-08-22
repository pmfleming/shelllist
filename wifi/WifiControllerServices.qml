import QtQuick

Item {
    id: services

    required property WifiController controller
    required property WifiPromptController prompt

    readonly property ShareAvailabilityController share: shareModel
    readonly property CaptivePortalController portal: portalModel
    readonly property WifiConnectPolicy policy: policyModel
    readonly property WifiConnectionController connection: connectionModel
    readonly property WifiAdvancedController advanced: advancedModel
    readonly property WifiNetworkActions actions: actionModel
    readonly property WifiScanController scan: scanModel
    readonly property NetworkHealthController health: healthModel
    readonly property HotspotController hotspot: hotspotModel
    readonly property VpnController vpn: vpnModel
    readonly property NetworkInventoryController inventory: inventoryModel
    readonly property NetworkStatisticsController statistics: statisticsModel
    readonly property WifiBackend backend: backendModel

    ShareAvailabilityController { id: shareModel; controller: services.controller; backend: backendModel }
    CaptivePortalController { id: portalModel; controller: services.controller; backend: backendModel }
    WifiConnectPolicy { id: policyModel }
    WifiConnectionController {
        id: connectionModel
        controller: services.controller
        backend: backendModel
        prompt: services.prompt
        policy: policyModel
        portal: portalModel
    }
    WifiAdvancedController { id: advancedModel; controller: services.controller; backend: backendModel }
    WifiNetworkActions { id: actionModel; controller: services.controller; backend: backendModel; prompt: services.prompt; portal: portalModel }
    WifiScanController { id: scanModel; controller: services.controller; backend: backendModel }
    NetworkHealthController { id: healthModel; controller: services.controller }
    HotspotController { id: hotspotModel; controller: services.controller; backend: backendModel }
    VpnController { id: vpnModel; controller: services.controller; backend: backendModel }
    NetworkInventoryController { id: inventoryModel; controller: services.controller; backend: backendModel }
    NetworkStatisticsController { id: statisticsModel; controller: services.controller; backend: backendModel }
    WifiBackend { id: backendModel; controller: services.controller }
}
