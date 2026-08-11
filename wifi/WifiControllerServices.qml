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
    WifiBackend { id: backendModel; controller: services.controller }
}
