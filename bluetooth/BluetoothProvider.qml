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
    function actionEnabled(capability) { return !controller.actionInFlight && !!capability; }
    function hasValue(value) { return value !== null && value !== undefined; }
    function connectionActions(device, caps) {
        return [
            Core.Model.keepOpenAction("pair", "Pair", {
                icon: "󰌾", shortcut: "P", role: "default",
                visible: !device.paired, enabled: actionEnabled(caps.can_pair),
                presentation: { group: "primary", tone: "active", width: 152 }
            }),
            Core.Model.keepOpenAction("connect", "Connect", {
                icon: "󰂱", shortcut: "C", role: "default",
                visible: !device.connected && device.paired, enabled: actionEnabled(caps.can_connect),
                presentation: { group: "primary", tone: "active", width: 152 }
            }),
            Core.Model.keepOpenAction("disconnect", "Disconnect", {
                icon: "󰂲", shortcut: "D", role: "destructive",
                visible: !!device.connected, enabled: actionEnabled(caps.can_disconnect),
                presentation: { group: "primary", tone: "danger", width: 152 }
            }),
            Core.Model.keepOpenAction("forget", "Forget", {
                icon: "󰆴", shortcut: "F", role: "destructive", enabled: actionEnabled(caps.can_remove),
                confirmation: { required: true, title: "Forget " + (device.name || "Bluetooth device") + "?", message: "Pairing information and saved trust will be deleted." },
                presentation: { group: "toolbar", tone: "normal", width: 92 }
            })
        ];
    }
    function settingActions(device, caps) {
        const multipoint = (device.fast_pair && device.fast_pair.multipoint) || ({});
        return [
            Core.Model.keepOpenAction("trusted", "Trusted", {
                shortcut: "T", kind: "toggle", enabled: actionEnabled(caps.can_trust),
                state: { checked: !!device.trusted }, presentation: { group: "settings", tone: "normal" }
            }),
            Core.Model.keepOpenAction("wake", "Wake computer", {
                shortcut: "W", kind: "toggle", visible: hasValue(device.wake_allowed),
                enabled: actionEnabled(caps.can_wake), state: { checked: !!device.wake_allowed },
                presentation: { group: "settings", tone: "normal" }
            }),
            Core.Model.keepOpenAction("multipoint", "Multipoint", {
                shortcut: "M", kind: "toggle", visible: !!multipoint.supported,
                enabled: actionEnabled(caps.can_set_multipoint), state: { checked: !!multipoint.enabled },
                presentation: { group: "settings", tone: "normal" }
            }),
            Core.Model.keepOpenAction("blocked", "Blocked", {
                shortcut: "B", kind: "toggle", enabled: actionEnabled(caps.can_block),
                state: { checked: !!device.blocked }, presentation: { group: "settings", tone: "danger" }
            })
        ];
    }
    function actionsForDevice(device) {
        const caps = device.capabilities || ({});
        return connectionActions(device, caps).concat(settingActions(device, caps));
    }
    function resultForDevice(device) {
        const batterySummary = BluetoothBattery.summary(device.battery || []);
        const battery = batterySummary.length > 0
            ? (" · " + batterySummary + (device.battery_last_known ? " · last known" : ""))
            : "";
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
        return executePayload(request, function (id, payload) { return controller.executeDeviceAction(id, payload); }, "Bluetooth action was rejected");
    }
}
