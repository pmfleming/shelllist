import QtQuick
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "BatteryApi.js" as BatteryApi
import "BatteryFlow.js" as Flow
import "BatteryPresentation.js" as Presentation

Ui.ChooserController {
    id: controller

    property var battery: ({
            available: false,
            percentage: 0,
            devices: [],
            policy: ({
                    warning_percent: 25,
                    critical_percent: 12,
                    notify_when_full: true,
                    notify_warning: true,
                    notify_critical: true,
                    warning_profile: "power-saver",
                    critical_profile: "power-saver",
                    recovery_margin_percent: 3
                }),
            protection: ({
                    supported: false,
                    managed: false,
                    enabled: false,
                    desired_enabled: false,
                    desired_start_percent: 75,
                    desired_end_percent: 80,
                    charge_once_active: false
                })
        })
    property var powerProfile: ({
            available: false,
            profile: "",
            profiles: [],
            performance_degraded: "",
            battery_aware: null,
            actions: [],
            active_holds: []
        })
    property var powerSleep: ({
            available: false,
            can_suspend: "no",
            can_hibernate: "no",
            preparing_for_sleep: false,
            lock_before_sleep: true,
            inhibitors: []
        })
    property var displayPolicyState: ({ available: false })
    property bool displayPolicySaving: false
    property string displayPolicyError: ""
    property var sleepPolicyState: ({ available: false })
    property var sleepPolicyDraft: ({
            lid_action: "system",
            same_profile: true,
            battery: { sleep_minutes: 30, hibernate_minutes: 0 },
            plugged: { sleep_minutes: 30, hibernate_minutes: 0 }
        })
    property bool sleepPolicyDirty: false
    property bool sleepPolicySaving: false
    property string sleepPolicyError: ""
    property string sleepPendingAction: ""
    property string sleepRetryAction: ""
    property string sleepError: ""
    property bool keepAwakePending: false
    property string keepAwakeError: ""
    readonly property bool keepAwake: powerSleep.keep_awake === true

    // With unavailable telemetry the only safe action is an idempotent release,
    // even if a degraded snapshot defaulted keep_awake to false.
    readonly property bool keepAwakeReleaseOnly: !powerSleep.available
    readonly property bool canSetKeepAwake: powerSleep.keep_awake !== undefined && backend.ready && !actionInFlight && !keepAwakePending && sleepPendingAction.length === 0 && (keepAwakeReleaseOnly || keepAwake || !powerSleep.preparing_for_sleep)
    readonly property bool sleepBusy: sleepPendingAction.length > 0 || !!powerSleep.preparing_for_sleep
    readonly property string sleepStatus: Presentation.sleepStatus(powerSleep, sleepPendingAction, sleepRetryAction, sleepError)
    property string lastError: ""
    property string refreshError: ""
    property string transportError: ""
    property string screenshotStatus: ""
    readonly property var viewTabs: [
        {
            value: "overview",
            icon: "󰋜",
            label: "Overview"
        },
        {
            value: "care",
            icon: "󰂂",
            label: "Battery care"
        },
        {
            value: "power",
            icon: "󰐥",
            label: "Power & sleep"
        }
    ]
    property string viewTab: "overview"
    property int selectedDeviceIndex: 0
    property bool draftProtectionEnabled: false
    property int draftStartPercent: 75
    property int draftEndPercent: 80
    property int draftWarningPercent: 25
    property int draftCriticalPercent: 12
    property bool draftNotifyWhenFull: true
    property bool draftNotifyWarning: true
    property bool draftNotifyCritical: true
    property string draftWarningProfile: "power-saver"
    property string draftCriticalProfile: "power-saver"
    property string lastWarningProfile: "power-saver"
    property string lastCriticalProfile: "power-saver"
    property bool thresholdDraftDirty: false
    property bool alertDraftDirty: false
    property bool thresholdEditing: false
    property bool alertEditing: false
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
    property var batteryHistory: ({
            points: [],
            last_charge_timestamp_ms: 0,
            latest_timestamp_ms: 0,
            retention_days: 7
        })
    property string energyPeriod: "last-charge"
    property var energyLastCharge: ({
            applications: [],
            total_energy_mwh: 0
        })
    property var energyWeek: ({
            applications: [],
            total_energy_mwh: 0
        })
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
    readonly property var energyOverview: energyPeriod === "week" ? energyWeek : energyLastCharge
    readonly property bool energyLoading: energyRequestsInFlight > 0
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
    readonly property var primaryDevice: selectedDevice
    readonly property var batteryOperation: battery.operation || ({
            kind: ""
        })
    readonly property bool operationForSelected: !!selectedDevice && batteryOperation.battery_id === selectedDevice.id
    readonly property bool chargingInhibited: operationForSelected && batteryOperation.kind === "inhibit"
    readonly property bool calibrating: operationForSelected && batteryOperation.kind === "calibration"
    readonly property bool batteryOperationActive: Flow.operationActive(battery)
    readonly property bool protectionSupported: !!selectedDevice && !!protection.supported
    readonly property bool inhibitionSupported: !!selectedDevice && (protection.available_behaviours || []).indexOf("inhibit-charge") >= 0
    readonly property bool calibrationSupported: protectionSupported && (protection.available_behaviours || []).indexOf("force-discharge") >= 0
    readonly property var profileOptions: (powerProfile.profiles || []).map(function (profile) {
        const labels = {
            "power-saver": "Power saver",
            "balanced": "Balanced",
            "performance": "Performance"
        };
        return {
            value: profile.name,
            label: labels[profile.name] || profile.name
        };
    })
    readonly property var levelProfileOptions: ["power-saver", "balanced", "performance"].map(function (name) {
        return {
            value: name,
            label: Presentation.profileName(name),
            enabled: powerProfile.available && profileOptions.some(function (option) { return option.value === name; })
        };
    })
    readonly property var batteryAutomation: powerProfile.battery_automation || ({})
    readonly property string automationStatus: Presentation.automationStatus(batteryAutomation, powerProfile.available)
    readonly property bool thresholdDraftValid: Presentation.thresholdRangeValid(draftStartPercent, draftEndPercent)
    readonly property bool alertDraftValid: Presentation.alertRangeValid(draftWarningPercent, draftCriticalPercent)
    readonly property bool settingsOperationActive: thresholdOperationActive || alertOperationActive
    readonly property string thresholdSaveStatus: !thresholdDraftValid ? "Choose a valid range" : (thresholdOperationActive ? "Applying automatically…" : (thresholdSaveError.length > 0 ? "Automatic apply failed" : (thresholdDraftDirty ? "Waiting to apply…" : "Applied automatically")))
    readonly property string alertSaveStatus: !alertDraftValid ? "Choose valid battery levels" : (alertOperationActive ? "Applying automatically…" : (alertSaveError.length > 0 ? "Automatic apply failed" : (alertDraftDirty ? "Waiting to apply…" : "Applied automatically")))

    function valueOr(value: var, fallback: var): var {
        return value === null || value === undefined ? fallback : value;
    }

    function selectViewTab(tab: string): void {
        if (viewTabs.some(function (option) {
            return option.value === tab;
        }))
            viewTab = tab;
    }

    function cycleViewTab(): bool {
        const index = viewTabs.findIndex(function (option) {
            return option.value === viewTab;
        });
        viewTab = viewTabs[(index + 1) % viewTabs.length].value;
        return true;
    }

    function syncBatterySelection(requestedId: string): void {
        const next = Flow.selection(battery, selectedDeviceIndex, requestedId);
        if ((selectedDevice ? selectedDevice.id : "") !== (next.device ? next.device.id : "")) {
            // Never apply a removed battery's pending range to its replacement.
            thresholdAutoSave.stop();
            thresholdDraftDirty = false;
            thresholdEditing = false;
            thresholdSaveError = "";
            thresholdRevision += 1;
            protectionAcknowledgedRevision = protectionRevision;
            protectionSentRevision = protectionRevision;
        }
        selectedDeviceIndex = next.index;
        selectedDevice = next.device;
        policy = next.policy;
        protection = next.protection;
    }

    function applyBattery(value: var): void {
        const nextBattery = value || ({
                available: false,
                percentage: 0,
                devices: []
            });
        const changes = Flow.historyChanges(nextBattery, batteryHistory);
        battery = nextBattery;
        if (uiActive && changes.history)
            backend.history();
        if (uiActive && changes.charge)
            requestEnergyPeriod("last-charge", true);
        syncBatterySelection(selectedDevice ? selectedDevice.id : "");
        syncThresholdDraft();
        if (!alertDraftDirty) {
            draftWarningPercent = Number(valueOr(policy.warning_percent, 25));
            draftCriticalPercent = Number(valueOr(policy.critical_percent, 12));
            draftNotifyWhenFull = valueOr(policy.notify_when_full, true);
            draftNotifyWarning = valueOr(policy.notify_warning, true);
            draftNotifyCritical = valueOr(policy.notify_critical, true);
            const legacyProfile = valueOr(policy.auto_power_saver, true) ? "power-saver" : "keep-current";
            draftWarningProfile = valueOr(policy.warning_profile, legacyProfile);
            draftCriticalProfile = valueOr(policy.critical_profile, legacyProfile);
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
        batteryHistory = value || ({
                points: [],
                last_charge_timestamp_ms: 0,
                latest_timestamp_ms: 0,
                retention_days: 7
            });
        if (uiActive && Number(batteryHistory.last_charge_timestamp_ms || 0) !== previousCharge)
            requestEnergyPeriod("last-charge", true);
    }

    function applyPowerProfile(value: var): void {
        powerProfile = value || ({
                available: false,
                profile: "",
                profiles: []
            });
    }

    function applyPowerSleep(value: var): void {
        if (value && value.available && !powerSleep.available && !keepAwakePending)
            keepAwakeError = "";
        powerSleep = value || ({
                available: false,
                inhibitors: []
            });
    }

    function applyDisplayPolicy(value: var): void {
        displayPolicyState = value || ({ available: false });
    }

    function setPreferExternal(enabled: bool): bool {
        if (typeof enabled !== "boolean" || !displayPolicyState.available || !backend.ready || actionInFlight || displayPolicySaving)
            return false;
        displayPolicySaving = true;
        displayPolicyError = "";
        actionInFlight = true;
        if (batteryBackend.setDisplayPolicy(enabled))
            return true;
        operationFailed("display-policy-", displayPolicyError || "Unable to save display preference");
        return false;
    }

    function applySleepPolicy(value: var): void {
        sleepPolicyState = value || ({ available: false });
        if (value && value.policy && !sleepPolicyDirty && !sleepPolicySaving)
            sleepPolicyDraft = JSON.parse(JSON.stringify(value.policy));
    }

    function updateSleepPolicy(profile: string, field: string, value: var): bool {
        if (!sleepPolicyState.available || sleepPolicySaving || actionInFlight)
            return false;
        const next = JSON.parse(JSON.stringify(sleepPolicyDraft));
        if (field === "same_profile") {
            if (typeof value !== "boolean")
                return false;
            next.same_profile = value;
        } else if (field === "lid_action") {
            if (!["system", "ignore", "lock", "suspend", "hibernate", "profile"].includes(value))
                return false;
            next.lid_action = value;
        } else {
            if (!["battery", "plugged"].includes(profile) || !["sleep_minutes", "hibernate_minutes"].includes(field) || !Number.isInteger(value) || value < 0 || value > 10080)
                return false;
            next[profile][field] = value;
        }
        sleepPolicyDraft = next;
        sleepPolicyDirty = true;
        return saveSleepPolicy();
    }

    function saveSleepPolicy(): bool {
        if (!sleepPolicyState.available || sleepPolicySaving || !sleepPolicyDirty || actionInFlight)
            return false;
        sleepPolicySaving = true;
        sleepPolicyError = "";
        if (!batteryBackend.setSleepPolicy(sleepPolicyDraft)) {
            sleepPolicyFailed("Unable to send automatic sleep settings");
            return false;
        }
        return true;
    }

    function sleepPolicyFinished(): void {
        sleepPolicySaving = false;
        sleepPolicyDirty = false;
        sleepPolicyError = "";
    }

    function sleepPolicyFailed(message: string): void {
        sleepPolicySaving = false;
        sleepPolicyError = message;
    }

    function selectDevice(batteryId: string): void {
        const devices = battery.devices || [];
        const index = devices.findIndex(function (device) {
            return device.id === batteryId;
        });
        if (index < 0 || actionInFlight || settingsOperationActive || (selectedDevice && selectedDevice.id === batteryId))
            return;
        thresholdAutoSave.stop();
        selectedDeviceIndex = index;
        syncBatterySelection(batteryId);
        syncThresholdDraft();
    }

    function applyDomainEvent(kind: string, data: var): void {
        const handlers = ({
                battery: applyBattery,
                powerProfile: applyPowerProfile,
                powerSleep: applyPowerSleep,
                sleepPolicy: applySleepPolicy,
                displayPolicy: applyDisplayPolicy
            });
        if (handlers[kind])
            handlers[kind](data);
    }
    function handleEvent(event: var): void {
        const kind = Flow.eventKind(event, BatteryApi.streams);
        if (kind)
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
        scheduleThresholdSave(false);
        finishAlertEditingIfIdle();
    }

    onBatteryOperationActiveChanged: {
        if (!batteryOperationActive)
            resumePendingSettings();
    }

    function operationFinished(id: string): void {
        if (id.startsWith("display-policy-")) {
            displayPolicySaving = false;
            displayPolicyError = "";
        }
        if (id.startsWith("power-keep-awake-")) {
            keepAwakePending = false;
            keepAwakeError = "";
        }
        if (id.startsWith("power-sleep-")) {
            sleepPendingAction = "";
            sleepRetryAction = "";
            sleepError = "";
        }
        actionInFlight = false;
        lastError = currentSettingsError();
        resumePendingSettings();
    }

    function operationFailed(id: string, message: string): void {
        actionInFlight = false;
        if (id.startsWith("display-policy-")) {
            displayPolicySaving = false;
            displayPolicyError = message;
            lastError = currentSettingsError();
        } else if (id.startsWith("power-keep-awake-")) {
            keepAwakePending = false;
            keepAwakeError = message;
            lastError = currentSettingsError();
        } else if (id.startsWith("power-sleep-")) {
            sleepPendingAction = "";
            sleepError = message;
            lastError = currentSettingsError();
        } else {
            lastError = message;
        }
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
                scheduleThresholdSave(false);
        } else {
            alertOperationActive = false;
            alertSaveError = "";
            if (alertRevision === alertSentRevision)
                alertDraftDirty = false;
            else
                finishAlertEditingIfIdle();
        }
        lastError = currentSettingsError();
    }

    function settingsOperationFailed(domain: string, message: string): void {
        lastError = message;
        if (domain === "threshold") {
            thresholdOperationActive = false;
            thresholdSaveError = message;
            if (thresholdRevision !== thresholdSentRevision)
                scheduleThresholdSave(false);
        } else {
            alertOperationActive = false;
            alertSaveError = message;
            if (alertRevision !== alertSentRevision)
                finishAlertEditingIfIdle();
        }
    }

    function transportFailed(message: string): void {
        transportError = message;
        if (displayPolicySaving) {
            displayPolicySaving = false;
            displayPolicyError = "Connection lost; the display preference may have been saved. " + message;
        }
        powerSleep = Object.assign({}, powerSleep, { available: false });
        if (keepAwakePending) {
            keepAwakePending = false;
            keepAwakeError = "Connection lost; Keep awake state is unknown until reconnected. " + message;
        }
        if (sleepPolicySaving)
            sleepPolicyFailed("Connection lost; settings may have been saved. Retry to confirm. " + message);
        thresholdAutoSave.stop();
        alertAutoSave.stop();
        if (sleepPendingAction.length > 0) {
            sleepPendingAction = "";
            sleepError = "Connection lost. The request may already have been accepted; check the session before retrying. " + message;
            lastError = currentSettingsError();
        } else if (actionInFlight) {
            // A recovered snapshot cannot confirm whether an effect succeeded.
            lastError = message;
        }
        actionInFlight = false;
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

    function refreshFinished(id: string): void {
        refreshError = "";
        if (id.startsWith("battery-snapshot-"))
            transportError = "";
    }

    function scheduleThresholdSave(immediate: bool): void {
        thresholdAutoSave.stop();
        if (thresholdEditing || !thresholdDraftValid || !thresholdDraftDirty)
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
        thresholdEditing = dragging;
        draftStartPercent = value;
        markThresholdChanged(false);
    }

    function updateEndPercent(value: int, dragging: bool): void {
        thresholdEditing = dragging;
        draftEndPercent = value;
        markThresholdChanged(false);
    }

    function finishThresholdEditing(): void {
        thresholdEditing = false;
        scheduleThresholdSave(false);
    }

    function markAlertChanged(immediate: bool): void {
        alertRevision += 1;
        alertDraftDirty = true;
        alertSaveError = "";
        alertAutoSave.stop();
        if (alertEditing || !alertDraftValid)
            return;
        if (immediate)
            flushAlertPolicy();
        else
            alertAutoSave.restart();
    }

    function updateWarningPercent(value: int, dragging: bool): void {
        alertEditing = dragging;
        draftWarningPercent = value;
        markAlertChanged(false);
    }

    function updateCriticalPercent(value: int, dragging: bool): void {
        alertEditing = dragging;
        draftCriticalPercent = value;
        markAlertChanged(false);
    }

    function finishAlertEditing(): void {
        alertEditing = false;
        finishAlertEditingIfIdle();
    }

    function finishAlertEditingIfIdle(): void {
        if (!alertEditing && alertDraftValid && alertDraftDirty)
            alertAutoSave.restart();
    }

    function updateNotifyWhenFull(value: bool): void {
        draftNotifyWhenFull = value;
        markAlertChanged(true);
    }

    function updateLevelNotification(level: string, value: bool): void {
        if (level === "low")
            draftNotifyWarning = value;
        else if (level === "critical")
            draftNotifyCritical = value;
        else
            return;
        markAlertChanged(true);
    }

    function updateLevelEnabled(level: string, enabled: bool): void {
        if (actionInFlight || (level !== "low" && level !== "critical"))
            return;
        const current = level === "low" ? draftWarningProfile : draftCriticalProfile;
        if (current !== "keep-current") {
            if (level === "low")
                lastWarningProfile = current;
            else
                lastCriticalProfile = current;
        }
        const previous = level === "low" ? lastWarningProfile : lastCriticalProfile;
        const option = levelProfileOptions.find(function (option) { return option.value === previous && option.enabled; })
            || levelProfileOptions.find(function (option) { return option.enabled; });
        // Notifications remain available even without a power-profile service.
        const profile = enabled && option ? option.value : "keep-current";
        if (level === "low") {
            draftNotifyWarning = enabled;
            draftWarningProfile = profile;
        } else {
            draftNotifyCritical = enabled;
            draftCriticalProfile = profile;
        }
        markAlertChanged(true);
    }

    function updateLevelProfile(level: string, value: string): void {
        if (value !== "keep-current" && !levelProfileOptions.some(function (option) { return option.value === value && option.enabled !== false; }))
            return;
        if (level === "low")
            draftWarningProfile = value;
        else if (level === "critical")
            draftCriticalProfile = value;
        else
            return;
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
        if (thresholdEditing || thresholdOperationActive || actionInFlight || batteryOperationActive || !protectionSupported || !thresholdDraftValid || !thresholdDraftDirty || !selectedDevice)
            return false;
        thresholdSentRevision = thresholdRevision;
        protectionSentRevision = protectionRevision;
        thresholdOperationActive = true;
        thresholdSaveError = "";
        lastError = "";
        const started = protectionRevision !== protectionAcknowledgedRevision ? backend.setProtection(selectedDevice.id, draftProtectionEnabled, draftStartPercent, draftEndPercent) : backend.setThresholds(selectedDevice.id, draftStartPercent, draftEndPercent);
        if (started)
            return true;
        thresholdOperationActive = false;
        thresholdSaveError = "Unable to send the battery protection policy";
        lastError = thresholdSaveError;
        return false;
    }

    function chargeOnce(): bool {
        if (actionInFlight || thresholdOperationActive || batteryOperationActive || !protectionSupported || !battery.plugged || !selectedDevice)
            return false;
        return startOperation(backend.chargeOnce(selectedDevice.id));
    }

    function setChargingInhibited(enabled: bool): bool {
        if (actionInFlight || thresholdOperationActive || !inhibitionSupported || !selectedDevice || (batteryOperationActive && !chargingInhibited))
            return false;
        return startOperation(backend.setChargingInhibited(selectedDevice.id, enabled));
    }

    function toggleCalibration(): bool {
        if (actionInFlight || thresholdOperationActive || !calibrationSupported || !selectedDevice || (!calibrating && (!battery.plugged || batteryOperationActive)))
            return false;
        return startOperation(calibrating ? backend.cancelCalibration(selectedDevice.id) : backend.startCalibration(selectedDevice.id));
    }

    function flushAlertPolicy(): bool {
        if (alertEditing || alertOperationActive || actionInFlight || !alertDraftValid || !alertDraftDirty)
            return false;
        alertSentRevision = alertRevision;
        alertOperationActive = true;
        alertSaveError = "";
        lastError = "";
        if (backend.setAlertPolicy({
            warning_percent: draftWarningPercent,
            critical_percent: draftCriticalPercent,
            notify_when_full: draftNotifyWhenFull,
            notify_warning: draftNotifyWarning,
            notify_critical: draftNotifyCritical,
            warning_profile: draftWarningProfile,
            critical_profile: draftCriticalProfile
        }))
            return true;
        alertOperationActive = false;
        alertSaveError = "Unable to send battery levels & actions";
        lastError = alertSaveError;
        return false;
    }

    function setPowerProfile(profile: string): bool {
        if (actionInFlight || !powerProfile.available || !profileOptions.some(function (option) {
            return option.value === profile;
        }))
            return false;
        return startOperation(backend.setPowerProfile(profile));
    }

    function resumeAutomaticProfiles(): bool {
        if (actionInFlight || !powerProfile.available || batteryAutomation.status !== "paused")
            return false;
        return startOperation(backend.resumeAutomaticProfiles());
    }

    function setBatteryAware(enabled: bool): bool {
        if (actionInFlight || !powerProfile.available || powerProfile.battery_aware === null || powerProfile.battery_aware === undefined)
            return false;
        return startOperation(backend.setBatteryAware(enabled));
    }

    function setPowerActionEnabled(action: string, enabled: bool): bool {
        if (actionInFlight || !powerProfile.available || !(powerProfile.actions || []).some(function (item) {
            return item.name === action;
        }))
            return false;
        return startOperation(backend.setPowerActionEnabled(action, enabled));
    }

    function toggleKeepAwake(): bool {
        return setKeepAwake(!keepAwakeReleaseOnly && !keepAwake);
    }

    function setKeepAwake(enabled: bool): bool {
        if (!canSetKeepAwake || typeof enabled !== "boolean" || (enabled && (keepAwakeReleaseOnly || sleepBusy)))
            return false;
        keepAwakePending = true;
        keepAwakeError = "";
        actionInFlight = true;
        if (batteryBackend.setKeepAwake(enabled))
            return true;
        operationFailed("power-keep-awake-", keepAwakeError || "Unable to change Keep awake");
        return false;
    }

    function canPowerSleepAction(action: string): bool {
        if (actionInFlight || sleepBusy || !powerSleep.available || ["lock", "suspend", "hibernate"].indexOf(action) < 0)
            return false;
        if (action !== "lock" && keepAwake)
            return false;
        if (action === "suspend" && !Presentation.sleepCapabilityAvailable(powerSleep.can_suspend))
            return false;
        if (action === "hibernate" && !Presentation.sleepCapabilityAvailable(powerSleep.can_hibernate))
            return false;
        return true;
    }

    function powerSleepAction(action: string): bool {
        if (!canPowerSleepAction(action))
            return false;
        // Set state before sending: transport rejection can be synchronous.
        sleepPendingAction = action;
        sleepRetryAction = action;
        sleepError = "";
        lastError = currentSettingsError();
        actionInFlight = true;
        if (backend.powerSleepAction(action))
            return true;
        operationFailed("power-sleep-" + action, sleepError || "Unable to send the request");
        return false;
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
        const request = Flow.energyRequest(period, forceRefresh, Date.now(), updated, Number(batteryHistory.last_charge_timestamp_ms || 0));
        if (!request)
            return;
        energyError = "";
        energyRequestsInFlight = 1;
        energyBackend.overview(request.period, request.since);
    }

    function storeEnergyOverview(period: string, overview: var): void {
        const value = overview || ({
                applications: [],
                total_energy_mwh: 0
            });
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
        const returnedPeriod = id.indexOf("battery-energy-last-charge-") === 0 ? "last-charge" : "week";
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

    BatteryBackend {
        id: batteryBackend
        controller: controller
    }
    BatteryEnergyBackend {
        id: batteryEnergyBackend
        controller: controller
    }
}
