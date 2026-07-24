import QtQuick
import Shelllist.Core as Core
import "WifiPresentation.js" as Presentation

Core.Provider {
    id: wifiProvider

    required property WifiController controller

    providerId: "wifi"
    displayName: "Wi-Fi"
    icon: "󰖩"
    priority: 100
    prefixes: ["wifi:"]
    capabilities: ({ query: false, actions: true, preview: true, subscriptions: true })

    function connectingTo(ap) {
        return controller.connection.running
            && controller.connection.networkName.length > 0
            && controller.networkName(ap) === controller.connection.networkName;
    }
    function primaryActions(ap, connecting) {
        return [
            Core.Model.keepOpenAction("connect", "Connect", {
                icon: "󰖩", shortcut: "C", role: "default",
                enabled: controller.actions.canConnect(ap),
                visible: !controller.isActive(ap) && !connecting,
                presentation: { group: "primary", tone: "active", width: 152 }
            }),
            Core.Model.keepOpenAction("cancel-connect", "Cancel", {
                icon: "󰜺", shortcut: "C", role: "destructive",
                enabled: controller.connection.requestId.length > 0,
                visible: connecting,
                presentation: { group: "primary", tone: "danger", width: 152 }
            }),
            Core.Model.keepOpenAction("disconnect", "Disconnect", {
                icon: "󰤭", shortcut: "D", role: "destructive",
                enabled: controller.actions.canDisconnect(ap),
                visible: controller.isActive(ap) && !connecting,
                presentation: { group: "primary", tone: "danger", width: 152 }
            })
        ];
    }
    function toolbarActions(ap) {
        return [
            Core.Model.keepOpenAction("forget", "Forget", {
                icon: "󰆴", shortcut: "F", role: "destructive",
                enabled: controller.actions.canForget(ap),
                confirmation: { required: true, title: "Forget network" },
                presentation: { group: "toolbar", tone: "normal", width: 92 }
            }),
            Core.Model.keepOpenAction("portal", "Sign in", {
                icon: "󰏌", shortcut: "I",
                presentation: { group: "toolbar", tone: "normal", width: 100 }
            }),
            Core.Model.keepOpenAction("share", "Share", {
                icon: "󰒖", shortcut: "S",
                enabled: controller.actions.canShare(ap),
                presentation: { group: "toolbar", tone: "normal", width: 92 }
            })
        ];
    }
    function settingsActions(ap) {
        return [
            Core.Model.keepOpenAction("autoconnect", "Auto-connect", {
                shortcut: "A", kind: "toggle",
                enabled: controller.actions.canProfileAction(ap, "can_toggle_autoconnect"),
                state: { checked: controller.actions.autoconnectEnabled(ap) },
                presentation: { group: "settings" }
            }),
            Core.Model.keepOpenAction("randomized-mac", "Randomize MAC address", {
                shortcut: "R", kind: "toggle",
                enabled: controller.actions.canProfileAction(ap, "can_set_mac_randomization"),
                state: { checked: controller.actions.randomizedMacEnabled(ap) },
                presentation: { group: "settings" }
            }),
            Core.Model.keepOpenAction("send-hostname", "Send device name", {
                shortcut: "N", kind: "toggle",
                enabled: controller.actions.canProfileAction(ap, "can_set_send_hostname"),
                state: { checked: controller.actions.sendHostnameEnabled(ap) },
                presentation: { group: "settings" }
            })
        ];
    }
    function actionsForNetwork(ap) {
        return ap ? primaryActions(ap, connectingTo(ap)).concat(toolbarActions(ap), settingsActions(ap)) : [];
    }

    function primaryActionId(ap) {
        if (controller.connection.running && controller.networkName(ap) === controller.connection.networkName)
            return "cancel-connect";
        return controller.isActive(ap) ? "disconnect" : "connect";
    }

    function resultForNetwork(network) {
        const security = Presentation.securityLabel(network.security);
        const strength = Math.max(0, Math.min(100, Number(network.strength) || 0));
        return Core.Model.result({
            providerId: providerId,
            providerPriority: priority,
            id: network.key || network.bssid || Presentation.networkName(network),
            title: Presentation.networkName(network),
            subtitle: strength + "% · " + security,
            icon: icon,
            score: (network.active ? 10000 : 0) + strength,
            keywords: [network.ssid, network.bssid, network.security, network.band],
            badges: network.active ? ["active"] : [],
            primaryActionId: primaryActionId(network),
            // Actions depend on live controller state and are supplied by actionsFor().
            actions: [],
            preview: { kind: "wifi-network", available: true },
            state: { active: !!network.active, busy: controller.connection.isConnecting(network) },
            payload: network
        });
    }

    function resultsForNetworks(networks) {
        return (networks || []).map(function (network) { return wifiProvider.resultForNetwork(network); });
    }

    function actionsFor(result) {
        return result && result.payload ? actionsForNetwork(result.payload) : [];
    }

    function primaryActionIdFor(result) {
        return result && result.payload ? primaryActionId(result.payload) : "";
    }

    function execute(request) {
        return executePayload(request, function (id, payload) { return controller.actions.execute(id, payload); }, "Wi-Fi action was rejected");
    }
}
