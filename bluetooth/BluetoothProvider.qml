import QtQuick
import Shelllist.Core as Core
import "BluetoothBattery.js" as BluetoothBattery
import "BluetoothFlow.js" as BluetoothFlow

Core.Provider {
    id: provider

    required property BluetoothController controller

    providerId: "bluetooth"
    displayName: "Bluetooth"
    icon: "󰂯"
    priority: 100
    prefixes: ["bluetooth:", "bt:"]
    capabilities: ({ query: false, actions: true, preview: true, subscriptions: true })

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
            Core.Model.keepOpenAction("pair", "Pair", { role: "default", shortcut: "Enter", visible: !device.paired, enabled: !!caps.can_pair }),
            Core.Model.keepOpenAction("connect", "Connect", { role: "default", shortcut: "Enter", visible: !device.connected && device.paired, enabled: !!caps.can_connect }),
            Core.Model.keepOpenAction("disconnect", "Disconnect", { role: "destructive", shortcut: "Enter", visible: !!device.connected, enabled: !!caps.can_disconnect }),
            Core.Model.keepOpenAction("trusted", "Trusted", { kind: "toggle", enabled: !!caps.can_trust, state: { checked: !!device.trusted } }),
            Core.Model.keepOpenAction("wake", "Wake computer", { kind: "toggle", visible: device.wake_allowed !== null && device.wake_allowed !== undefined, enabled: !!caps.can_wake, state: { checked: !!device.wake_allowed } }),
            Core.Model.keepOpenAction("blocked", "Blocked", { kind: "toggle", enabled: !!caps.can_block, state: { checked: !!device.blocked } }),
            Core.Model.keepOpenAction("remove", "Remove device", { role: "destructive", enabled: !!caps.can_remove, confirmation: { required: true, title: "Remove Bluetooth device", message: "Pairing information will be deleted." } })
        ];
    }
    function resultForDevice(device) {
        const batterySummary = BluetoothBattery.summary(device.battery || []);
        const battery = batterySummary.length > 0 ? (" · " + batterySummary) : "";
        return Core.Model.result({
            providerId: providerId,
            providerPriority: priority,
            id: device.key,
            title: device.name,
            subtitle: BluetoothFlow.deviceState(device) + battery,
            icon: icon,
            score: BluetoothFlow.deviceScore(device),
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
