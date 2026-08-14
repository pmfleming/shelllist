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

    function primaryActionId(device: var): string {
        if (device.blocked) return "blocked";
        if (device.connected) return "disconnect";
        if (!device.paired) return "pair";
        return "connect";
    }
    function actionEnabled(capability: bool, device: var): bool {
        return !controller.globalRequestInFlight && !controller.deviceBusy(device.key) && capability;
    }
    function unsupported(caps: var, operation: string): string {
        return (caps.unsupported_reasons || ({}))[operation] || "";
    }
    function primaryPresentation(tone: string): var {
        return { group: "primary", tone: tone, width: 152 };
    }
    function settingPresentation(tone: string): var {
        return { group: "settings", tone: tone || "normal" };
    }

    function connectionActions(device: var, caps: var): var {
        return [
            Core.Model.keepOpenAction("pair", "Pair", {
                icon: "󰌾", shortcut: "P", role: "default", visible: !device.paired,
                enabled: actionEnabled(caps.can_pair, device), presentation: primaryPresentation("active")
            }),
            Core.Model.keepOpenAction("connect", "Connect", {
                icon: "󰂱", shortcut: "C", role: "default", visible: !device.connected && device.paired,
                enabled: actionEnabled(caps.can_connect, device), presentation: primaryPresentation("active")
            }),
            Core.Model.keepOpenAction("disconnect", "Disconnect", {
                icon: "󰂲", shortcut: "D", role: "destructive", visible: !!device.connected,
                enabled: actionEnabled(caps.can_disconnect, device), presentation: primaryPresentation("danger")
            }),
            Core.Model.keepOpenAction("forget", "Forget", {
                icon: "󰆴", shortcut: "F", role: "destructive", enabled: actionEnabled(caps.can_remove, device),
                confirmation: { required: true, title: "Forget " + (device.name || "Bluetooth device") + "?",
                    message: "Pairing information and saved trust will be deleted." },
                presentation: { group: "toolbar", tone: "normal", width: 92 },
                metadata: { disabledReason: unsupported(caps, "remove") }
            })
        ];
    }

    function trustAction(device: var, caps: var): var {
        return Core.Model.keepOpenAction("trusted", "Trusted", {
            shortcut: "T", kind: "toggle", enabled: actionEnabled(caps.can_trust, device),
            state: { checked: !!device.trusted }, presentation: settingPresentation("normal"),
            metadata: { disabledReason: unsupported(caps, "trust") }
        });
    }
    function wakeAction(device: var, caps: var): var {
        const supported = device.wake_allowed !== null && device.wake_allowed !== undefined;
        return Core.Model.keepOpenAction("wake", "Wake computer", {
            shortcut: "W", kind: "toggle", visible: supported,
            enabled: actionEnabled(caps.can_wake, device), state: { checked: !!device.wake_allowed },
            presentation: settingPresentation("normal"), metadata: { disabledReason: unsupported(caps, "wake") }
        });
    }
    function multipointAction(device: var, caps: var): var {
        const multipoint = (device.fast_pair && device.fast_pair.multipoint) || ({});
        return Core.Model.keepOpenAction("multipoint", "Multipoint", {
            shortcut: "M", kind: "toggle", visible: !!multipoint.supported,
            enabled: actionEnabled(caps.can_set_multipoint, device), state: { checked: !!multipoint.enabled },
            presentation: settingPresentation("normal"), metadata: { disabledReason: unsupported(caps, "set_multipoint") }
        });
    }
    function blockAction(device: var, caps: var): var {
        return Core.Model.keepOpenAction("blocked", "Blocked", {
            shortcut: "B", kind: "toggle", enabled: actionEnabled(caps.can_block, device),
            state: { checked: !!device.blocked }, presentation: settingPresentation("danger"),
            metadata: { disabledReason: unsupported(caps, "block") }
        });
    }
    function settingActions(device: var, caps: var): var {
        return [trustAction(device, caps), wakeAction(device, caps),
            multipointAction(device, caps), blockAction(device, caps)];
    }
    function actionsForDevice(device: var): var {
        const caps = device.capabilities || ({});
        return connectionActions(device, caps).concat(settingActions(device, caps));
    }

    function deviceSubtitle(device: var, operation: var, operationError: var): string {
        if (operation)
            return BluetoothFlow.activeOperationStatus(operation, device.name || "Bluetooth device");
        if (operationError)
            return (operationError.message || "Last operation failed") + " · retry available";
        const batterySummary = BluetoothBattery.summary(device.battery || []);
        const battery = batterySummary ? " · " + batterySummary : "";
        const lastKnown = battery && device.battery_last_known ? " · last known" : "";
        return BluetoothFlow.deviceState(device) + battery + lastKnown;
    }

    function resultForDevice(device: var): var {
        const operation = controller.operationForDevice(device.key);
        const operationError = controller.operationErrorForDevice(device.key);
        return Core.Model.result({
            providerId: providerId, providerPriority: priority, id: device.key,
            title: BluetoothFlow.deviceDisplayName(device, controller.allDevices, controller.adapters),
            subtitle: deviceSubtitle(device, operation, operationError),
            icon: BluetoothGlyphs.forListDevice(device), score: BluetoothFlow.deviceScore(device),
            keywords: [device.name, device.icon || ""], badges: device.connected ? ["active"] : [],
            primaryActionId: primaryActionId(device), actions: [],
            preview: { kind: "bluetooth-device", available: true },
            state: { active: !!device.connected, busy: !!operation, error: !!operationError }, payload: device
        });
    }
    function resultsForDevices(devices: var): var {
        return (devices || []).map(function (device) { return provider.resultForDevice(device); });
    }
    function actionsFor(result: var): var { return result && result.payload ? actionsForDevice(result.payload) : []; }
    function primaryActionIdFor(result: var): string { return result && result.payload ? primaryActionId(result.payload) : ""; }
    function execute(request: var): bool {
        return executePayload(request,
            function (id, payload) { return controller.executeDeviceAction(id, payload); });
    }
}
