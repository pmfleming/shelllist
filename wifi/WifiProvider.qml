import QtQuick
import Shelllist.Core as Core
import "WifiPresentation.js" as Presentation

Core.Provider {
    required property WifiController controller

    providerId: "wifi"
    displayName: "Wi-Fi"
    icon: "󰖩"
    priority: 100
    prefixes: ["wifi:"]
    capabilities: ({
            query: false,
            actions: true,
            preview: true,
            subscriptions: true
        })

    function primaryActions(ap, connecting) {
        return [Core.Model.keepOpenAction("connect", "Connect", {
                accessKey: "C",
                icon: "󰖩",
                role: "default",
                enabled: controller.actions.canConnect(ap),
                visible: !controller.isActive(ap) && !connecting,
                presentation: {
                    tone: "active"
                }
            }), Core.Model.keepOpenAction("cancel-connect", "Cancel", {
                accessKey: "X",
                icon: "󰜺",
                role: "destructive",
                enabled: controller.connection.requestId.length > 0,
                visible: connecting,
                presentation: {
                    group: "primary"
                }
            }), Core.Model.keepOpenAction("disconnect", "Disconnect", {
                accessKey: "D",
                icon: "󰤭",
                role: "destructive",
                enabled: controller.actions.canDisconnect(ap),
                visible: controller.isActive(ap) && !connecting,
                presentation: {
                    group: "primary"
                }
            })];
    }
    function toolbarActions(ap) {
        return [Core.Model.keepOpenAction("forget", "Forget", {
                accessKey: "F",
                icon: "󰆴",
                role: "destructive",
                enabled: controller.actions.canForget(ap),
                confirmation: {
                    required: true,
                    title: "Forget network"
                },
                presentation: {
                    group: "toolbar",
                    tone: "normal"
                }
            }), Core.Model.keepOpenAction("portal", "Sign in", {
                accessKey: "I",
                icon: "󰏌",
                presentation: {
                    group: "toolbar"
                }
            }), Core.Model.keepOpenAction("share", "Share", {
                accessKey: "H",
                icon: "󰒖",
                enabled: controller.actions.canShare(ap),
                presentation: {
                    group: "toolbar"
                }
            })];
    }
    function settingsActions(ap) {
        return [Core.Model.settingToggle("autoconnect", "Auto-connect", controller.actions.autoconnectEnabled(ap), {
                enabled: controller.actions.canProfileAction(ap, "can_toggle_autoconnect")
            }), Core.Model.settingToggle("randomized-mac", "Randomize MAC address", controller.actions.randomizedMacEnabled(ap), {
                enabled: controller.actions.canProfileAction(ap, "can_set_mac_randomization")
            }), Core.Model.settingToggle("send-hostname", "Send device name", controller.actions.sendHostnameEnabled(ap), {
                enabled: controller.actions.canProfileAction(ap, "can_set_send_hostname")
            })];
    }
    function actionsForNetwork(ap) {
        return ap ? primaryActions(ap, controller.connection.isConnecting(ap)).concat(toolbarActions(ap), settingsActions(ap)) : [];
    }

    function primaryActionId(ap) {
        if (controller.connection.isConnecting(ap))
            return "cancel-connect";
        return controller.isActive(ap) ? "disconnect" : "connect";
    }

    function resultFor(network: var): var {
        const security = Presentation.securityLabel(network.security);
        const strength = Math.max(0, Math.min(100, Number(network.strength) || 0));
        return makeResult({
            id: network.key || network.bssid || Presentation.networkName(network),
            title: Presentation.networkName(network),
            subtitle: Presentation.bandLabel(network) + " · " + security,
            icon: icon,
            score: (network.active ? 10000 : 0) + strength,
            keywords: [network.ssid, network.bssid, network.security, network.band],
            badges: network.active ? ["active"] : [],
            primaryActionId: primaryActionId(network),
            // Actions depend on live controller state and are supplied by actionsFor().
            actions: [],
            preview: {
                kind: "wifi-network",
                available: true
            },
            state: {
                active: !!network.active,
                busy: controller.connection.isConnecting(network)
            },
            payload: network
        });
    }

    function actionsFor(result) {
        return result && result.payload ? actionsForNetwork(result.payload) : [];
    }

    function primaryActionIdFor(result) {
        return result && result.payload ? primaryActionId(result.payload) : "";
    }

    function execute(request) {
        return executePayload(request, function (id, payload) {
            return controller.actions.execute(id, payload);
        });
    }
}
