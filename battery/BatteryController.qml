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
    property var powerSleep: ({ available: false, can_suspend: "no", can_hibernate: "no",
        preparing_for_sleep: false, lock_before_sleep: true, inhibitors: [] })
    property string lastError: ""
    property string refreshError: ""
    property int selectedDeviceIndex: 0
    property int draftStartPercent: 75
    property int draftEndPercent: 80
    property int draftWarningPercent: 25
    property int draftCriticalPercent: 12
    property bool draftNotifyWhenFull: true
    property bool draftAutoPowerSaver: true
    property bool thresholdDraftDirty: false
    property bool alertDraftDirty: false
    property var batteryHistory: ({ points: [], last_charge_timestamp_ms: 0,
        latest_timestamp_ms: 0, retention_days: 7 })
    property string energyPeriod: "last-charge"
    property var energyLastCharge: ({ applications: [], total_energy_mwh: 0 })
    property var energyWeek: ({ applications: [], total_energy_mwh: 0 })
    property double energyLastChargeUpdatedMs: 0
    property double energyWeekUpdatedMs: 0
    property string energyError: ""
    property int energyRequestsInFlight: 0

    detailsOpen: false
    navigationPrimaryEnabled: false
    readonly property BatteryBackend backend: batteryBackend
    readonly property BatteryEnergyBackend energyBackend: batteryEnergyBackend
    readonly property var policy: battery.policy || ({})
    readonly property var energyOverview: energyPeriod === "week"
        ? energyWeek : energyLastCharge
    readonly property bool energyLoading: energyRequestsInFlight > 0
    readonly property var selectedDevice: battery.devices && battery.devices.length > selectedDeviceIndex
        ? battery.devices[selectedDeviceIndex] : null
    readonly property var primaryDevice: selectedDevice
    readonly property var protection: selectedDevice && selectedDevice.protection
        ? selectedDevice.protection : (battery.protection || ({}))
    readonly property var batteryOperation: battery.operation || ({ kind: "" })
    readonly property bool operationForSelected: !!selectedDevice
        && batteryOperation.battery_id === selectedDevice.id
    readonly property bool chargingInhibited: operationForSelected
        && batteryOperation.kind === "inhibit"
    readonly property bool calibrating: operationForSelected
        && batteryOperation.kind === "calibration"
    readonly property bool batteryOperationActive: !!batteryOperation.kind
    readonly property bool protectionSupported: !!protection.supported
    readonly property bool inhibitionSupported: (protection.available_behaviours || [])
        .indexOf("inhibit-charge") >= 0
    readonly property bool calibrationSupported: protectionSupported
        && (protection.available_behaviours || []).indexOf("force-discharge") >= 0
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
        const nextBattery = value || ({ available: false, percentage: 0, devices: [] });
        const historySummary = nextBattery.history || ({});
        const nextHistoryTimestamp = Number(historySummary.latest_timestamp_ms || 0);
        const historyChanged = nextHistoryTimestamp > 0
            && nextHistoryTimestamp !== Number(batteryHistory.latest_timestamp_ms || 0);
        const chargeChanged = Number(historySummary.last_charge_timestamp_ms || 0) > 0
            && Number(historySummary.last_charge_timestamp_ms)
                !== Number(batteryHistory.last_charge_timestamp_ms || 0);
        battery = nextBattery;
        if (uiActive && historyChanged)
            backend.history();
        if (uiActive && chargeChanged)
            requestEnergyPeriod("last-charge", true);
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

    function applyBatteryHistory(value: var): void {
        const previousCharge = Number(batteryHistory.last_charge_timestamp_ms || 0);
        batteryHistory = value || ({ points: [], last_charge_timestamp_ms: 0,
            latest_timestamp_ms: 0, retention_days: 7 });
        if (uiActive && Number(batteryHistory.last_charge_timestamp_ms || 0) !== previousCharge)
            requestEnergyPeriod("last-charge", true);
    }

    function applyPowerProfile(value: var): void {
        powerProfile = value || ({ available: false, profile: "", profiles: [] });
    }

    function applyPowerSleep(value: var): void {
        powerSleep = value || ({ available: false, inhibitors: [] });
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
            refreshAll();
            return;
        }
        if ((event.event === "subscribed" || event.event === "changed")
                && event.stream === BatteryApi.streams.battery)
            applyBattery(event.data || ({}));
        if ((event.event === "subscribed" || event.event === "changed")
                && event.stream === BatteryApi.streams.powerProfile)
            applyPowerProfile(event.data || ({}));
        if ((event.event === "subscribed" || event.event === "changed")
                && event.stream === BatteryApi.streams.powerSleep)
            applyPowerSleep(event.data || ({}));
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

    function refreshFailed(_id: string, message: string): void {
        if (uiActive)
            refreshError = message;
    }

    function refreshFinished(_id: string): void {
        refreshError = "";
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
        if (actionInFlight || batteryOperationActive || !protectionSupported)
            return false;
        return startOperation(backend.setProtection(selectedDevice.id, enabled));
    }

    function applyThresholds(): bool {
        if (actionInFlight || batteryOperationActive || !protectionSupported || !thresholdDraftValid
                || !primaryDevice)
            return false;
        return startOperation(backend.setThresholds(primaryDevice.id,
            draftStartPercent, draftEndPercent));
    }

    function chargeOnce(): bool {
        if (actionInFlight || batteryOperationActive || !protectionSupported || !battery.plugged)
            return false;
        return startOperation(backend.chargeOnce(selectedDevice.id));
    }

    function setChargingInhibited(enabled: bool): bool {
        if (actionInFlight || !inhibitionSupported || !selectedDevice
                || (batteryOperationActive && !chargingInhibited))
            return false;
        return startOperation(backend.setChargingInhibited(selectedDevice.id, enabled));
    }

    function toggleCalibration(): bool {
        if (actionInFlight || !calibrationSupported || !selectedDevice
                || (batteryOperationActive && !calibrating))
            return false;
        return startOperation(calibrating
            ? backend.cancelCalibration(selectedDevice.id)
            : backend.startCalibration(selectedDevice.id));
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

    function powerSleepAction(action: string): bool {
        if (actionInFlight || !powerSleep.available)
            return false;
        if (action === "suspend" && !Presentation.sleepCapabilityAvailable(
                powerSleep.can_suspend))
            return false;
        if (action === "hibernate" && !Presentation.sleepCapabilityAvailable(
                powerSleep.can_hibernate))
            return false;
        return startOperation(backend.powerSleepAction(action));
    }

    function selectEnergyPeriod(period: string): void {
        if (period !== "last-charge" && period !== "week")
            return;
        energyPeriod = period;
        requestEnergyPeriod(period, false);
    }

    function requestEnergyPeriod(period: string, forceRefresh: bool): void {
        if (!uiActive || energyRequestsInFlight > 0)
            return;
        const now = Date.now();
        const updated = period === "week" ? energyWeekUpdatedMs : energyLastChargeUpdatedMs;
        if (!forceRefresh && now - updated < 60000)
            return;
        const weekSince = now - 7 * 24 * 60 * 60 * 1000;
        const chargeSince = Number(batteryHistory.last_charge_timestamp_ms || 0);
        energyError = "";
        energyRequestsInFlight = 1;
        energyBackend.overview(period,
            period === "week" || chargeSince <= 0 ? weekSince : chargeSince);
    }

    function applyEnergyOverview(id: string, overview: var): void {
        energyRequestsInFlight = 0;
        energyError = "";
        const returnedPeriod = id.indexOf("battery-energy-last-charge-") === 0
            ? "last-charge" : "week";
        if (returnedPeriod === "last-charge") {
            energyLastCharge = overview || ({ applications: [], total_energy_mwh: 0 });
            energyLastChargeUpdatedMs = Date.now();
        } else {
            energyWeek = overview || ({ applications: [], total_energy_mwh: 0 });
            energyWeekUpdatedMs = Date.now();
        }
        if (returnedPeriod !== energyPeriod)
            requestEnergyPeriod(energyPeriod, false);
    }

    function energyOverviewFailed(_id: string, message: string): void {
        energyRequestsInFlight = 0;
        energyError = message;
    }

    function energyTransportFailed(message: string): void {
        energyRequestsInFlight = 0;
        energyError = message;
    }

    function refreshAll(): void {
        backend.snapshot();
        backend.history();
        requestEnergyPeriod(energyPeriod, true);
    }

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        refreshAll();
    }

    function deactivateUi() {
        energyRequestsInFlight = 0;
        deactivateUiState();
    }

    Timer {
        interval: 60000
        repeat: true
        running: controller.uiActive
        onTriggered: controller.requestEnergyPeriod(controller.energyPeriod, true)
    }

    BatteryBackend { id: batteryBackend; controller: controller }
    BatteryEnergyBackend { id: batteryEnergyBackend; controller: controller }
}
