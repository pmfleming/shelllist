import QtQuick
import "core" as Core
import "core/Model.js" as Model
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

    function actionDefinition(id, label, options) {
        const values = options || ({});
        return Model.action({
            id: id,
            label: label,
            icon: values.icon || "",
            shortcut: values.shortcut || "",
            role: values.role || "secondary",
            kind: values.kind || "command",
            enabled: values.enabled !== false,
            visible: values.visible !== false,
            closePolicy: "keep-open",
            confirmation: values.confirmation || ({}),
            state: values.state || ({}),
            presentation: values.presentation || ({})
        });
    }

    function actionsForNetwork(ap) {
        if (!ap)
            return [];
        const connectingThis = controller.connectRunning
            && controller.connectingNetworkName.length > 0
            && controller.networkName(ap) === controller.connectingNetworkName;
        return [
            actionDefinition("connect", "Connect", {
                icon: "󰖩", shortcut: "C", role: "default",
                enabled: controller.canConnectNetwork(ap),
                visible: !controller.isActive(ap) && !connectingThis,
                presentation: { group: "primary", tone: "active", width: 152 }
            }),
            actionDefinition("cancel-connect", "Cancel", {
                icon: "󰜺", shortcut: "C", role: "destructive",
                enabled: controller.activeConnectRequestId.length > 0,
                visible: connectingThis,
                presentation: { group: "primary", tone: "danger", width: 152 }
            }),
            actionDefinition("disconnect", "Disconnect", {
                icon: "󰤭", shortcut: "D", role: "destructive",
                enabled: controller.canDisconnectNetwork(ap),
                visible: controller.isActive(ap) && !connectingThis,
                presentation: { group: "primary", tone: "danger", width: 152 }
            }),
            actionDefinition("forget", "Forget", {
                icon: "󰆴", shortcut: "F", role: "destructive",
                enabled: controller.canForgetNetwork(ap),
                confirmation: { required: true, title: "Forget network" },
                presentation: { group: "toolbar", tone: "normal", width: 92 }
            }),
            actionDefinition("portal", "Sign in", {
                icon: "󰏌", shortcut: "I",
                presentation: { group: "toolbar", tone: "normal", width: 100 }
            }),
            actionDefinition("share", "Share", {
                icon: "󰒖", shortcut: "S",
                enabled: controller.canShareNetwork(ap),
                presentation: { group: "toolbar", tone: "normal", width: 92 }
            }),
            actionDefinition("autoconnect", "Auto-connect", {
                shortcut: "A", kind: "toggle",
                enabled: controller.canProfileActionFor(ap, "can_toggle_autoconnect"),
                state: { checked: controller.autoconnectEnabledFor(ap) },
                presentation: { group: "settings" }
            }),
            actionDefinition("randomized-mac", "Randomize MAC address", {
                shortcut: "R", kind: "toggle",
                enabled: controller.canProfileActionFor(ap, "can_set_mac_randomization"),
                state: { checked: controller.randomizedMacEnabledFor(ap) },
                presentation: { group: "settings" }
            }),
            actionDefinition("send-hostname", "Send device name", {
                shortcut: "N", kind: "toggle",
                enabled: controller.canProfileActionFor(ap, "can_set_send_hostname"),
                state: { checked: controller.sendHostnameEnabledFor(ap) },
                presentation: { group: "settings" }
            })
        ];
    }

    function primaryActionId(ap) {
        if (controller.connectRunning && controller.networkName(ap) === controller.connectingNetworkName)
            return "cancel-connect";
        return controller.isActive(ap) ? "disconnect" : "connect";
    }

    function resultForNetwork(network) {
        const security = Presentation.securityLabel(network.security);
        const strength = Math.max(0, Math.min(100, Number(network.strength) || 0));
        return Model.result({
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
            actions: actionsForNetwork(network),
            preview: { kind: "wifi-network", available: true },
            state: { active: !!network.active, busy: controller.isConnecting(network) },
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
        if (!request || !request.result || !request.result.payload)
            return false;
        executionStarted(request);
        const accepted = controller.executeNetworkAction(request.actionId, request.result.payload);
        if (accepted === false) {
            executionFailed({ requestId: request.id, code: "action-rejected", message: "Wi-Fi action was rejected" });
            return false;
        }
        return true;
    }
}
