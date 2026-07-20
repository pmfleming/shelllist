import QtQuick
import Shelllist.Core as Core
import "BluetoothBattery.js" as BluetoothBattery

Core.Provider {
    id: provider

    required property var controller

    providerId: "bluetooth"
    displayName: "Bluetooth"
    icon: "󰂯"
    priority: 100
    prefixes: ["bluetooth:", "bt:"]
    capabilities: ({ query: false, actions: true, preview: true, subscriptions: true })

    function action(id, label, options) {
        const values = options || ({});
        return Core.Model.action({
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
    function primaryActionId(device) {
        if (device.connected)
            return "disconnect";
        if (!device.paired)
            return "pair";
        return "connect";
    }
    function actionsForDevice(device) {
        const caps = device.capabilities || ({});
        return [
            action("pair", "Pair", { role: "default", shortcut: "Enter", visible: !device.paired, enabled: !!caps.can_pair }),
            action("connect", "Connect", { role: "default", shortcut: "Enter", visible: !device.connected && device.paired, enabled: !!caps.can_connect }),
            action("disconnect", "Disconnect", { role: "destructive", shortcut: "Enter", visible: !!device.connected, enabled: !!caps.can_disconnect }),
            action("trusted", "Trusted", { kind: "toggle", enabled: !!caps.can_trust, state: { checked: !!device.trusted } }),
            action("wake", "Wake computer", { kind: "toggle", visible: device.wake_allowed !== null && device.wake_allowed !== undefined, enabled: !!caps.can_wake, state: { checked: !!device.wake_allowed } }),
            action("blocked", "Blocked", { kind: "toggle", enabled: !!caps.can_block, state: { checked: !!device.blocked } }),
            action("remove", "Remove device", { role: "destructive", enabled: !!caps.can_remove, confirmation: { required: true, title: "Remove Bluetooth device", message: "Pairing information will be deleted." } })
        ];
    }
    function resultForDevice(device) {
        const batterySummary = BluetoothBattery.summary(device.battery || []);
        const battery = batterySummary.length > 0 ? (" · " + batterySummary) : "";
        const state = device.connected ? "Connected" : (device.paired ? "Paired" : (device.present ? "Available" : "Not in range"));
        return Core.Model.result({
            providerId: providerId,
            providerPriority: priority,
            id: device.key,
            title: device.name,
            subtitle: state + battery,
            icon: icon,
            score: (device.connected ? 10000 : 0) + (device.paired ? 1000 : 0) + (device.signal_strength || 0),
            keywords: [device.name, device.icon || ""],
            badges: device.connected ? ["active"] : [],
            primaryActionId: primaryActionId(device),
            // Actions depend on live controller state and are supplied by actionsFor().
            actions: [],
            preview: { kind: "bluetooth-device", available: true },
            state: { active: !!device.connected, busy: controller.actionInFlight },
            payload: device
        });
    }
    function resultsForDevices(devices) { return (devices || []).map(function (device) { return provider.resultForDevice(device); }); }
    function actionsFor(result) { return result && result.payload ? actionsForDevice(result.payload) : []; }
    function primaryActionIdFor(result) { return result && result.payload ? primaryActionId(result.payload) : ""; }
    function execute(request) {
        if (!request || !request.result || !request.result.payload)
            return false;
        executionStarted(request);
        if (!controller.executeDeviceAction(request.actionId, request.result.payload)) {
            executionFailed({ requestId: request.id, code: "action-rejected", message: "Bluetooth action was rejected" });
            return false;
        }
        return true;
    }
}
