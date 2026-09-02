import QtQuick
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "BatteryApi.js" as BatteryApi
import "BatteryFlow.js" as Flow
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
    property string screenshotStatus: ""
    property string viewTab: "battery"
    property int selectedDeviceIndex: 0
    property bool draftProtectionEnabled: false
    property int draftStartPercent: 75
    property int draftEndPercent: 80
    property int draftWarningPercent: 25
    property int draftCriticalPercent: 12
    property bool draftNotifyWhenFull: true
    property bool draftAutoPowerSaver: true
    property bool thresholdDraftDirty: false
    property bool alertDraftDirty: false
    property bool thresholdOperationActive: false
    property bool alertOperationActive: false
    property int thresholdRevision: 0
    property int thresholdSentRevision: 0
    property int protectionRevision: 0
    property int protectionAcknowledgedRevision: 0
    property int protectionSentRevision: 0
    property int alertRevision: 0
    property int alertSentRevision: 0
    property string thresholdSaveError: ""
    property string alertSaveError: ""
    property var batteryHistory: ({ points: [], last_charge_timestamp_ms: 0,
        latest_timestamp_ms: 0, retention_days: 7 })
    property string energyPeriod: "last-charge"
    property var energyLastCharge: ({ applications: [], total_energy_mwh: 0 })
    property var energyWeek: ({ applications: [], total_energy_mwh: 0 })
    property double energyLastChargeUpdatedMs: 0
    property double energyWeekUpdatedMs: 0
    property string energyError: ""
    property int energyRequestsInFlight: 0
    property var policy: ({})
    property var selectedDevice: null
    property var protection: ({})

    detailsOpen: false
    navigationPrimaryEnabled: false
    readonly property BatteryBackend backend: batteryBackend
    readonly property BatteryEnergyBackend energyBackend: batteryEnergyBackend
    readonly property var energyOverview: energyPeriod === "week"
        ? energyWeek : energyLastCharge
    readonly property bool energyLoading: energyRequestsInFlight > 0
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
    readonly property var primaryDevice: selectedDevice
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
    readonly property bool settingsOperationActive: thresholdOperationActive
        || alertOperationActive
    readonly property string thresholdSaveStatus: !thresholdDraftValid
        ? "Choose a valid range"
        : (thresholdOperationActive ? "Applying automatically…"
            : (thresholdSaveError.length > 0 ? "Automatic apply failed"
                : (thresholdDraftDirty ? "Waiting to apply…" : "Applied automatically")))
    readonly property string alertSaveStatus: !alertDraftValid
        ? "Choose a valid alert range"
        : (alertOperationActive ? "Applying automatically…"
            : (alertSaveError.length > 0 ? "Automatic apply failed"
                : (alertDraftDirty ? "Waiting to apply…" : "Applied automatically")))

    function valueOr(value: var, fallback: var): var {
        return value === null || value === undefined ? fallback : value;
    }

    function selectViewTab(tab: string): void {
        if (tab === "battery" || tab === "power")
            viewTab = tab;
    }

    function cycleViewTab(): bool {
        viewTab = viewTab === "battery" ? "power" : "battery";
        return true;
    }

    function syncBatterySelection(): void {
        const next = Flow.selection(battery, selectedDeviceIndex);
        selectedDeviceIndex = next.index;
        selectedDevice = next.device;
        policy = next.policy;
        protection = next.protection;
    }

    function applyBattery(value: var): void {
        const nextBattery = value || ({ available: false, percentage: 0, devices: [] });
        const changes = Flow.historyChanges(nextBattery, batteryHistory);
        battery = nextBattery;
        if (uiActive && changes.history)
            backend.history();
        if (uiActive && changes.charge)
            requestEnergyPeriod("last-charge", true);
        syncBatterySelection();
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
            draftProtectionEnabled = !!protection.desired_enabled;
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
        if (index < 0 || actionInFlight || settingsOperationActive)
            return;
        thresholdAutoSave.stop();
        selectedDeviceIndex = index;
        syncBatterySelection();
        thresholdDraftDirty = false;
        thresholdSaveError = "";
        protectionAcknowledgedRevision = protectionRevision;
        protectionSentRevision = protectionRevision;
        syncThresholdDraft();
    }

    function applyDomainEvent(kind: string, data: var): void {
        const handlers = ({
            battery: applyBattery,
            powerProfile: applyPowerProfile,
            powerSleep: applyPowerSleep
        });
        if (handlers[kind])
            handlers[kind](data);
    }
    function handleEvent(event: var): void {
        const kind = Flow.eventKind(event, BatteryApi.streams);
        if (kind === "lagged")
            refreshAll();
        else if (kind)
            applyDomainEvent(kind, event.data || ({}));
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

    function currentSettingsError(): string {
        return thresholdSaveError.length > 0 ? thresholdSaveError : alertSaveError;
    }

    function resumePendingSettings(): void {
        if (thresholdDraftDirty && thresholdDraftValid && !thresholdOperationActive)
            thresholdAutoSave.restart();
        if (alertDraftDirty && alertDraftValid && !alertOperationActive)
            alertAutoSave.restart();
    }

    function operationFinished(_id: string): void {
        actionInFlight = false;
        lastError = currentSettingsError();
        resumePendingSettings();
    }

    function operationFailed(_id: string, message: string): void {
        actionInFlight = false;
        lastError = message;
        resumePendingSettings();
    }

    function settingsOperationFinished(domain: string): void {
        if (domain === "threshold") {
            thresholdOperationActive = false;
            thresholdSaveError = "";
            protectionAcknowledgedRevision = protectionSentRevision;
            if (thresholdRevision === thresholdSentRevision)
                thresholdDraftDirty = false;
            else
                thresholdAutoSave.restart();
        } else {
            alertOperationActive = false;
            alertSaveError = "";
            if (alertRevision === alertSentRevision)
                alertDraftDirty = false;
            else
                alertAutoSave.restart();
        }
        lastError = currentSettingsError();
    }

    function settingsOperationFailed(domain: string, message: string): void {
        lastError = message;
        if (domain === "threshold") {
            thresholdOperationActive = false;
            thresholdSaveError = message;
            if (thresholdRevision !== thresholdSentRevision)
                thresholdAutoSave.restart();
        } else {
            alertOperationActive = false;
            alertSaveError = message;
            if (alertRevision !== alertSentRevision)
                alertAutoSave.restart();
        }
    }

    function transportFailed(message: string): void {
        thresholdAutoSave.stop();
        alertAutoSave.stop();
        actionInFlight = false;
        lastError = message;
        if (thresholdOperationActive) {
            thresholdOperationActive = false;
            thresholdSaveError = message;
        }
        if (alertOperationActive) {
            alertOperationActive = false;
            alertSaveError = message;
        }
    }

    function refreshFailed(_id: string, message: string): void {
        if (uiActive)
            refreshError = message;
    }

    function refreshFinished(_id: string): void {
        refreshError = "";
    }

    function scheduleThresholdSave(immediate: bool): void {
        thresholdAutoSave.stop();
        if (!thresholdDraftValid || !thresholdDraftDirty)
            return;
        if (immediate)
            flushThresholdPolicy();
        else
            thresholdAutoSave.restart();
    }

    function markThresholdChanged(immediate: bool): void {
        thresholdRevision += 1;
        thresholdDraftDirty = true;
        thresholdSaveError = "";
        scheduleThresholdSave(immediate);
    }

    function updateStartPercent(value: int, dragging: bool): void {
        draftStartPercent = value;
        markThresholdChanged(false);
        if (dragging)
            thresholdAutoSave.stop();
    }

    function updateEndPercent(value: int, dragging: bool): void {
        draftEndPercent = value;
        markThresholdChanged(false);
        if (dragging)
            thresholdAutoSave.stop();
    }

    function finishThresholdEditing(): void {
        scheduleThresholdSave(false);
    }

    function markAlertChanged(immediate: bool): void {
        alertRevision += 1;
        alertDraftDirty = true;
        alertSaveError = "";
        alertAutoSave.stop();
        if (!alertDraftValid)
            return;
        if (immediate)
            flushAlertPolicy();
        else
            alertAutoSave.restart();
    }

    function updateWarningPercent(value: int, dragging: bool): void {
        draftWarningPercent = value;
        markAlertChanged(false);
        if (dragging)
            alertAutoSave.stop();
    }

    function updateCriticalPercent(value: int, dragging: bool): void {
        draftCriticalPercent = value;
        markAlertChanged(false);
        if (dragging)
            alertAutoSave.stop();
    }

    function finishAlertEditing(): void {
        if (alertDraftValid && alertDraftDirty)
            alertAutoSave.restart();
    }

    function updateNotifyWhenFull(value: bool): void {
        draftNotifyWhenFull = value;
        markAlertChanged(true);
    }

    function updateAutoPowerSaver(value: bool): void {
        draftAutoPowerSaver = value;
        markAlertChanged(true);
    }

    function setProtection(enabled: bool): bool {
        if (actionInFlight || batteryOperationActive || !protectionSupported || !selectedDevice)
            return false;
        draftProtectionEnabled = enabled;
        protectionRevision += 1;
        markThresholdChanged(true);
        return true;
    }

    function flushThresholdPolicy(): bool {
        if (thresholdOperationActive || actionInFlight || batteryOperationActive
                || !protectionSupported || !thresholdDraftValid || !thresholdDraftDirty
                || !selectedDevice)
            return false;
        thresholdSentRevision = thresholdRevision;
        protectionSentRevision = protectionRevision;
        thresholdOperationActive = true;
        thresholdSaveError = "";
        lastError = "";
        const started = protectionRevision !== protectionAcknowledgedRevision
            ? backend.setProtection(selectedDevice.id, draftProtectionEnabled,
                draftStartPercent, draftEndPercent)
            : backend.setThresholds(selectedDevice.id, draftStartPercent, draftEndPercent);
        if (started)
            return true;
        thresholdOperationActive = false;
        thresholdSaveError = "Unable to send the battery protection policy";
        lastError = thresholdSaveError;
        return false;
    }

    function chargeOnce(): bool {
        if (actionInFlight || thresholdOperationActive || batteryOperationActive
                || !protectionSupported || !battery.plugged || !selectedDevice)
            return false;
        return startOperation(backend.chargeOnce(selectedDevice.id));
    }

    function setChargingInhibited(enabled: bool): bool {
        if (actionInFlight || thresholdOperationActive || !inhibitionSupported || !selectedDevice
                || (batteryOperationActive && !chargingInhibited))
            return false;
        return startOperation(backend.setChargingInhibited(selectedDevice.id, enabled));
    }

    function toggleCalibration(): bool {
        if (actionInFlight || thresholdOperationActive || !calibrationSupported || !selectedDevice
                || (batteryOperationActive && !calibrating))
            return false;
        return startOperation(calibrating
            ? backend.cancelCalibration(selectedDevice.id)
            : backend.startCalibration(selectedDevice.id));
    }

    function flushAlertPolicy(): bool {
        if (alertOperationActive || actionInFlight || !alertDraftValid || !alertDraftDirty)
            return false;
        alertSentRevision = alertRevision;
        alertOperationActive = true;
        alertSaveError = "";
        lastError = "";
        if (backend.setAlertPolicy(draftWarningPercent, draftCriticalPercent,
                draftNotifyWhenFull, draftAutoPowerSaver))
            return true;
        alertOperationActive = false;
        alertSaveError = "Unable to send the battery alert policy";
        lastError = alertSaveError;
        return false;
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
        const updated = period === "week" ? energyWeekUpdatedMs : energyLastChargeUpdatedMs;
        const request = Flow.energyRequest(period, forceRefresh, Date.now(), updated,
            Number(batteryHistory.last_charge_timestamp_ms || 0));
        if (!request)
            return;
        energyError = "";
        energyRequestsInFlight = 1;
        energyBackend.overview(request.period, request.since);
    }

    function storeEnergyOverview(period: string, overview: var): void {
        const value = overview || ({ applications: [], total_energy_mwh: 0 });
        if (period === "last-charge") {
            energyLastCharge = value;
            energyLastChargeUpdatedMs = Date.now();
        } else {
            energyWeek = value;
            energyWeekUpdatedMs = Date.now();
        }
    }
    function applyEnergyOverview(id: string, overview: var): void {
        energyRequestsInFlight = 0;
        energyError = "";
        const returnedPeriod = id.indexOf("battery-energy-last-charge-") === 0
            ? "last-charge" : "week";
        storeEnergyOverview(returnedPeriod, overview);
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

    function captureScreenshot(x: real, y: real, width: real, height: real): bool {
        return screenshotCapture.captureRegion(x, y, width, height);
    }

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        refreshAll();
    }

    function deactivateUi() {
        energyRequestsInFlight = 0;
        screenshotStatus = "";
        deactivateUiState();
    }

    Io.ClipboardScreenshotCapture {
        id: screenshotCapture
        active: controller.uiActive
        blocked: controller.actionInFlight || controller.settingsOperationActive
        startMessage: "Capturing Battery & Power panel…"
        onStatusChanged: function (message) {
            controller.screenshotStatus = message;
            if (!inFlight)
                screenshotStatusTimer.restart();
        }
    }

    Timer {
        id: screenshotStatusTimer
        interval: 2500
        repeat: false
        onTriggered: controller.screenshotStatus = ""
    }

    Timer {
        id: thresholdAutoSave
        interval: 500
        repeat: false
        onTriggered: controller.flushThresholdPolicy()
    }

    Timer {
        id: alertAutoSave
        interval: 500
        repeat: false
        onTriggered: controller.flushAlertPolicy()
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
