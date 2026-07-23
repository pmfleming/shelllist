import QtQuick
import Shelllist.Core as Core

Item {
    id: services

    required property WifiController controller
    required property WifiPromptController prompt

    property alias queryText: resultsModel.queryText
    property alias selectedIndex: resultsModel.selectedIndex
    readonly property Core.ProviderRegistry providers: providerRegistry
    readonly property WifiProvider provider: wifiProvider
    readonly property Core.ResultStore results: resultsModel
    readonly property ShareAvailabilityController share: shareModel
    readonly property CaptivePortalController portal: portalModel
    readonly property WifiConnectPolicy policy: policyModel
    readonly property WifiConnectionController connection: connectionModel
    readonly property WifiAdvancedController advanced: advancedModel
    readonly property WifiNetworkActions actions: actionModel
    readonly property WifiScanController scan: scanModel
    readonly property WifiNavigation navigation: navigationModel
    readonly property WifiBackend backend: backendModel

    Core.ProviderRegistry {
        id: providerRegistry
        WifiProvider { id: wifiProvider; controller: services.controller }
    }
    Core.ResultStore { id: resultsModel; registry: providerRegistry }
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
    WifiNavigation {
        id: navigationModel
        controller: services.controller
        blocked: services.prompt.open || !services.controller.powered
    }
    WifiBackend { id: backendModel; controller: services.controller }
}
