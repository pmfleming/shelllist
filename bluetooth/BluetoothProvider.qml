import QtQuick
import Shelllist.Core as Core
import "BluetoothBattery.js" as BluetoothBattery
import "BluetoothFlow.js" as BluetoothFlow
import "BluetoothGlyphs.js" as BluetoothGlyphs

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
        const idle = !controller.actionInFlight;
        return [
            Core.Model.keepOpenAction("pair", "Pair", {
                icon: "󰌾", shortcut: "P", role: "default",
                visible: !device.paired, enabled: idle && !!caps.can_pair,
                presentation: { group: "primary", tone: "active", width: 152 }
            }),
            Core.Model.keepOpenAction("connect", "Connect", {
                icon: "󰂱", shortcut: "C", role: "default",
                visible: !device.connected && device.paired, enabled: idle && !!caps.can_connect,
                presentation: { group: "primary", tone: "active", width: 152 }
            }),
            Core.Model.keepOpenAction("disconnect", "Disconnect", {
                icon: "󰂲", shortcut: "D", role: "destructive",
                visible: !!device.connected, enabled: idle && !!caps.can_disconnect,
                presentation: { group: "primary", tone: "danger", width: 152 }
            }),
            Core.Model.keepOpenAction("remove", "Remove device", {
                icon: "󰆴", shortcut: "R", role: "destructive",
                enabled: idle && !!caps.can_remove,
                confirmation: { required: true, title: "Remove " + (device.name || "Bluetooth device") + "?", message: "Pairing information and saved trust will be deleted." },
                presentation: { group: "toolbar", tone: "danger", width: 132 }
            }),
            Core.Model.keepOpenAction("trusted", "Trusted", {
                shortcut: "T", kind: "toggle", enabled: idle && !!caps.can_trust,
                state: { checked: !!device.trusted }, presentation: { group: "settings", tone: "normal" }
            }),
            Core.Model.keepOpenAction("wake", "Wake computer", {
                shortcut: "W", kind: "toggle",
                visible: device.wake_allowed !== null && device.wake_allowed !== undefined,
                enabled: idle && !!caps.can_wake, state: { checked: !!device.wake_allowed },
                presentation: { group: "settings", tone: "normal" }
            }),
            Core.Model.keepOpenAction("blocked", "Blocked", {
                shortcut: "B", kind: "toggle", enabled: idle && !!caps.can_block,
                state: { checked: !!device.blocked }, presentation: { group: "settings", tone: "danger" }
            })
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
            icon: BluetoothGlyphs.forDevice(device),
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
