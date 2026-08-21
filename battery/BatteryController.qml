import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui
import "BatteryApi.js" as BatteryApi
import "BatteryPresentation.js" as Presentation

Ui.ChooserController {
    id: controller

    property var battery: ({ available: false, percentage: 0, devices: [],
        policy: ({ warning_percent: 25, critical_percent: 12, notify_when_full: true,
            auto_power_saver: true }),
        protection: ({ supported: false, managed: false, enabled: false,
            desired_enabled: false, desired_start_percent: 75,
            desired_end_percent: 80, charge_once_active: false }) })
    property var powerProfile: ({ available: false, profile: "", profiles: [],
        performance_degraded: "", battery_aware: null, actions: [], active_holds: [] })
    property string lastError: ""
    property int selectedDeviceIndex: 0
    property int draftStartPercent: 75
    property int draftEndPercent: 80
    property int draftWarningPercent: 25
    property int draftCriticalPercent: 12
    property bool draftNotifyWhenFull: true
    property bool draftAutoPowerSaver: true
    property bool thresholdDraftDirty: false
    property bool alertDraftDirty: false

    detailsOpen: false
    navigationPrimaryEnabled: false
    readonly property BatteryBackend backend: batteryBackend
    readonly property var policy: battery.policy || ({})
    readonly property var selectedDevice: battery.devices && battery.devices.length > selectedDeviceIndex
        ? battery.devices[selectedDeviceIndex] : null
    readonly property var primaryDevice: selectedDevice
    readonly property var protection: selectedDevice && selectedDevice.protection
        ? selectedDevice.protection : (battery.protection || ({}))
    readonly property bool protectionSupported: !!protection.supported
    readonly property var profileOptions: (powerProfile.profiles || []).map(function (profile) {
        const labels = { "power-saver": "Power saver", "balanced": "Balanced",
            "performance": "Performance" };
        return { value: profile.name, label: labels[profile.name] || profile.name };
    })
    readonly property bool thresholdDraftValid: Presentation.thresholdRangeValid(
        draftStartPercent, draftEndPercent)
    readonly property bool alertDraftValid: Presentation.alertRangeValid(
        draftWarningPercent, draftCriticalPercent)

    function valueOr(value: var, fallback: var): var {
        return value === null || value === undefined ? fallback : value;
    }

    function applyBattery(value: var): void {
        battery = value || ({ available: false, percentage: 0, devices: [] });
        if (selectedDeviceIndex >= (battery.devices || []).length)
            selectedDeviceIndex = 0;
        syncThresholdDraft();
        if (!alertDraftDirty) {
            draftWarningPercent = Number(valueOr(policy.warning_percent, 25));
            draftCriticalPercent = Number(valueOr(policy.critical_percent, 12));
            draftNotifyWhenFull = valueOr(policy.notify_when_full, true);
            draftAutoPowerSaver = valueOr(policy.auto_power_saver, true);
        }
    }

    function syncThresholdDraft(): void {
        if (!thresholdDraftDirty) {
            draftStartPercent = Number(valueOr(protection.desired_start_percent, 75));
            draftEndPercent = Number(valueOr(protection.desired_end_percent, 80));
        }
    }

    function applyPowerProfile(value: var): void {
        powerProfile = value || ({ available: false, profile: "", profiles: [] });
    }

    function selectDevice(batteryId: string): void {
        const devices = battery.devices || [];
        const index = devices.findIndex(function (device) { return device.id === batteryId; });
        if (index < 0 || actionInFlight)
            return;
        selectedDeviceIndex = index;
        thresholdDraftDirty = false;
        syncThresholdDraft();
    }

    function handleEvent(event: var): void {
        const compatibility = Core.ApiEnvelope.compatibilityError(event,
            BatteryApi.protocol, BatteryApi.version, "bar-daemon");
        if (compatibility.length > 0) {
            lastError = compatibility;
            return;
        }
        if (event.event === "lagged") {
            backend.snapshot();
            return;
        }
        if ((event.event === "subscribed" || event.event === "changed")
                && event.stream === BatteryApi.streams.battery)
            applyBattery(event.data || ({}));
        if ((event.event === "subscribed" || event.event === "changed")
                && event.stream === BatteryApi.streams.powerProfile)
            applyPowerProfile(event.data || ({}));
    }

    function startOperation(started: bool): bool {
        if (!started) {
            lastError = "Unable to send the battery operation";
            return false;
        }
        lastError = "";
        actionInFlight = true;
        return true;
    }

    function operationFinished(id: string): void {
        actionInFlight = false;
        lastError = "";
        if (id.startsWith("battery-thresholds"))
            thresholdDraftDirty = false;
        if (id.startsWith("battery-alerts"))
            alertDraftDirty = false;
    }

    function operationFailed(message: string): void {
        actionInFlight = false;
        lastError = message;
    }

    function updateStartPercent(value: int): void {
        draftStartPercent = value;
        thresholdDraftDirty = true;
    }

    function updateEndPercent(value: int): void {
        draftEndPercent = value;
        thresholdDraftDirty = true;
    }

    function updateWarningPercent(value: int): void {
        draftWarningPercent = value;
        alertDraftDirty = true;
    }

    function updateCriticalPercent(value: int): void {
        draftCriticalPercent = value;
        alertDraftDirty = true;
    }

    function updateNotifyWhenFull(value: bool): void {
        draftNotifyWhenFull = value;
        alertDraftDirty = true;
    }

    function updateAutoPowerSaver(value: bool): void {
        draftAutoPowerSaver = value;
        alertDraftDirty = true;
    }

    function setProtection(enabled: bool): bool {
        if (actionInFlight || !protectionSupported)
            return false;
        return startOperation(backend.setProtection(selectedDevice.id, enabled));
    }

    function applyThresholds(): bool {
        if (actionInFlight || !protectionSupported || !thresholdDraftValid
                || !primaryDevice)
            return false;
        return startOperation(backend.setThresholds(primaryDevice.id,
            draftStartPercent, draftEndPercent));
    }

    function chargeOnce(): bool {
        if (actionInFlight || !protectionSupported || !battery.plugged)
            return false;
        return startOperation(backend.chargeOnce(selectedDevice.id));
    }

    function applyAlertPolicy(): bool {
        if (actionInFlight || !alertDraftValid)
            return false;
        return startOperation(backend.setAlertPolicy(draftWarningPercent,
            draftCriticalPercent, draftNotifyWhenFull, draftAutoPowerSaver));
    }

    function setPowerProfile(profile: string): bool {
        if (actionInFlight || !powerProfile.available)
            return false;
        return startOperation(backend.setPowerProfile(profile));
    }

    function setBatteryAware(enabled: bool): bool {
        if (actionInFlight || powerProfile.battery_aware === null
                || powerProfile.battery_aware === undefined)
            return false;
        return startOperation(backend.setBatteryAware(enabled));
    }

    function setPowerActionEnabled(action: string, enabled: bool): bool {
        if (actionInFlight || !action.length)
            return false;
        return startOperation(backend.setPowerActionEnabled(action, enabled));
    }

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        backend.snapshot();
    }

    BatteryBackend { id: batteryBackend; controller: controller }
}
