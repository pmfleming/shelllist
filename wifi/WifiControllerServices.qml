import QtQuick
import Shelllist.Core as Core

Item {
    id: services

    required property WifiController controller
    required property WifiPromptController prompt

    property alias queryText: resultsModel.queryText
    property alias selectedIndex: resultsModel.selectedIndex
    readonly property alias providers: providerRegistry
    readonly property alias provider: wifiProvider
    readonly property alias results: resultsModel
    readonly property alias share: shareModel
    readonly property alias portal: portalModel
    readonly property alias policy: policyModel
    readonly property alias connection: connectionModel
    readonly property alias advanced: advancedModel
    readonly property alias actions: actionModel
    readonly property alias scan: scanModel
    readonly property alias navigation: navigationModel
    readonly property alias backend: backendModel

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
    WifiNavigation { id: navigationModel; controller: services.controller }
    WifiBackend { id: backendModel; controller: services.controller }
}
