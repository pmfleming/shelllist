import QtQuick
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "BatteryApi.js" as BatteryApi
import "BatteryFlow.js" as Flow
import "BatteryFeedback.js" as Presentation

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

    // Telemetry and policy fields retain bar-api v1 keys for daemon compatibility.
    property var powerSuspend: ({
            available: false,
            can_suspend: "no",
            can_hibernate: "no",
            preparing_for_sleep: false,
            lock_before_sleep: true,
            inhibitors: []
        })
    property var suspendPolicyState: ({
            available: false
        })
    property var suspendPolicyDraft: ({
            lid_action: "system",
            same_profile: true,
            battery: {
                sleep_minutes: 30,
                hibernate_minutes: 0
            },
            plugged: {
                sleep_minutes: 30,
                hibernate_minutes: 0
            }
        })
    property bool suspendPolicyDirty: false
    property bool suspendPolicySaving: false
    property bool suspendPolicyCriticalOnly: false
    property string suspendPolicyError: ""
    property string suspendPendingAction: ""
    property string suspendRetryAction: ""
    property string suspendError: ""
    property bool keepAwakePending: false
    property string keepAwakeError: ""
    readonly property bool keepAwake: powerSuspend.keep_awake === true

    // With unavailable telemetry the only safe action is an idempotent release,
    // even if a degraded snapshot defaulted keep_awake to false.
    readonly property bool keepAwakeReleaseOnly: !powerSuspend.available
    readonly property bool canSetKeepAwake: powerSuspend.keep_awake !== undefined && backend.ready && !actionInFlight && !keepAwakePending && suspendPendingAction.length === 0 && (keepAwakeReleaseOnly || keepAwake || !powerSuspend.preparing_for_sleep)
    readonly property bool suspendOutcomeUnknown: (powerSuspend.operation || {}).phase === "unknown"
    readonly property bool suspendBusy: suspendPendingAction.length > 0 || !!powerSuspend.preparing_for_sleep || ["requested", "dispatching", "accepted", "preparing", "returned"].includes((powerSuspend.operation || {}).phase)
    readonly property string suspendStatus: Presentation.suspendStatus(powerSuspend, suspendPendingAction, suspendRetryAction, suspendError)
    property string lastError: ""
    property string refreshError: ""
    property string transportError: ""
    property alias screenshotStatus: screenshotCapture.statusMessage
    readonly property var viewTabs: [
        {
            value: "overview",
            icon: "󰋜",
            label: "Overview"
        },
        {
            value: "care",
            icon: "󰂂",
            label: "Care"
        },
        {
            value: "power",
            icon: "󰐥",
            label: "Power"
        }
    ]
    viewMemory: Ui.ChooserMemory {
        controller: controller
        key: "battery::settings"
        tab: controller.viewTab
        initialTab: controller.viewTab
        tabs: controller.viewTabs.map(item => item.value)
        presentationOpen: true
        onRestoreRequested: function (open, tab) { controller.viewTab = tab; }
    }
    function cycleDetailsTab(backwards: bool) {
        cycleViewTab(backwards);
    }
    property string viewTab: "overview"
    property int selectedDeviceIndex: 0
    readonly property BatterySettings settings: batterySettings
    property int historyHours: 6
    function requestHistory(hours: int): void {
        historyHours = hours;
        if (uiActive) backend.history();
    }
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
            label: labels[profile.name] || profile.name,
            icon: BatteryPresentation.lookup(BatteryPresentation.profiles, profile.name, {}).icon || "",
            iconColor: Ui.Theme.batteryControlColors[profile.name] || Ui.Theme.text,
            selectedIconColor: Ui.Theme.batteryControlColors[profile.name] || Ui.Theme.selectedText
        };
    })
    readonly property var levelProfileOptions: ["power-saver", "balanced", "performance"].map(function (name) {
        return {
            value: name,
            label: Presentation.profileName(name),
            icon: BatteryPresentation.lookup(BatteryPresentation.profiles, name, {}).icon || "",
            enabled: powerProfile.available && profileOptions.some(function (option) {
                return option.value === name;
            })
        };
    })
    readonly property var batteryAutomation: powerProfile.battery_automation || ({})
    readonly property string automationStatus: Presentation.automationStatus(batteryAutomation, powerProfile.available)

    function selectViewTab(tab: string): void {
        if (viewTabs.some(function (option) {
            return option.value === tab;
        }))
            viewTab = tab;
    }

    function cycleViewTab(backwards: bool): bool {
        viewTab = tabAfter(viewTabs.map(option => option.value), viewTab, backwards);
        return true;
    }

    function syncBatterySelection(requestedId: string): void {
        const next = Flow.selection(battery, selectedDeviceIndex, requestedId);
        if ((selectedDevice ? selectedDevice.id : "") !== (next.device ? next.device.id : "")) {
            // Never apply a removed battery's pending range to its replacement.
            settings.resetSelection();
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
        if (uiActive && (changes.history || (nextBattery.history?.current_point?.timestamp_ms !== batteryHistory.current_point?.timestamp_ms)))
            backend.history();
        if (uiActive && changes.charge)
            requestEnergyPeriod("last-charge", true);
        syncBatterySelection(selectedDevice ? selectedDevice.id : "");
        settings.syncDrafts();
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

    function applyPowerSuspend(value: var): void {
        if (value && value.available && !powerSuspend.available && !keepAwakePending)
            keepAwakeError = "";
        powerSuspend = value || ({
                available: false,
                inhibitors: []
            });
    }

    function applySuspendPolicy(value: var): void {
        suspendPolicyState = value || ({
                available: false
            });
        if (value && value.policy && !suspendPolicyDirty && !suspendPolicySaving)
            suspendPolicyDraft = JSON.parse(JSON.stringify(value.policy));
    }

    function updateSuspendPolicy(profile: string, field: string, value: var): bool {
        if ((!suspendPolicyState.available && profile !== "critical_battery") || suspendPolicySaving || actionInFlight)
            return false;
        const next = Flow.editSuspendPolicy(suspendPolicyDraft, profile, field, value);
        if (!next)
            return false;
        suspendPolicyDraft = next;
        suspendPolicyCriticalOnly = profile === "critical_battery" && (!suspendPolicyDirty || suspendPolicyCriticalOnly);
        suspendPolicyDirty = true;
        return saveSuspendPolicy();
    }

    function updateSleepTimeline(profile: string, endpoint: string, value: real): bool {
        if (!suspendPolicyState.available || suspendPolicySaving || actionInFlight)
            return false;
        const next = Flow.editSleepTimeline(suspendPolicyDraft, profile, endpoint, value, !!suspendPolicyState.hibernate_available);
        if (!next) return false;
        suspendPolicyDraft = next;
        suspendPolicyCriticalOnly = false;
        suspendPolicyDirty = true;
        return saveSuspendPolicy();
    }

    function saveSuspendPolicy(): bool {
        if ((!suspendPolicyState.available && !suspendPolicyCriticalOnly) || suspendPolicySaving || !suspendPolicyDirty || actionInFlight)
            return false;
        suspendPolicySaving = true;
        suspendPolicyError = "";
        const sent = suspendPolicyCriticalOnly ? batteryBackend.setCriticalPolicy(suspendPolicyDraft.critical_battery) : batteryBackend.setSuspendPolicy(suspendPolicyDraft);
        if (!sent) {
            suspendPolicyFailed("Unable to send automatic suspend settings");
            return false;
        }
        return true;
    }

    function cancelCriticalBattery(): bool {
        if (actionInFlight || !["countdown", "acting"].includes((suspendPolicyState.critical_battery || {}).phase))
            return false;
        return startOperation(batteryBackend.cancelCriticalBattery());
    }

    function suspendPolicyFinished(): void {
        suspendPolicySaving = false;
        suspendPolicyDirty = false;
        suspendPolicyError = "";
    }

    function suspendPolicyFailed(message: string): void {
        suspendPolicySaving = false;
        suspendPolicyError = message;
    }

    function selectDevice(batteryId: string): void {
        const devices = battery.devices || [];
        const index = devices.findIndex(function (device) {
            return device.id === batteryId;
        });
        if (index < 0 || actionInFlight || settings.operationActive || (selectedDevice && selectedDevice.id === batteryId))
            return;
        selectedDeviceIndex = index;
        syncBatterySelection(batteryId);
        settings.syncThresholdDraft();
    }

    function applyDomainEvent(kind: string, data: var): void {
        const handlers = ({
                battery: applyBattery,
                powerProfile: applyPowerProfile,
                powerSuspend: applyPowerSuspend,
                suspendPolicy: applySuspendPolicy
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

    onBatteryOperationActiveChanged: {
        if (!batteryOperationActive)
            settings.resume();
    }

    function operationFinished(id: string): void {
        if (id.startsWith("power-keep-awake-")) {
            keepAwakePending = false;
            keepAwakeError = "";
        }
        if (id.startsWith("power-suspend-")) {
            suspendPendingAction = "";
            suspendRetryAction = "";
            suspendError = "";
        }
        actionInFlight = false;
        lastError = settings.error;
        settings.resume();
    }

    function operationFailed(id: string, message: string): void {
        actionInFlight = false;
        if (id.startsWith("power-keep-awake-")) {
            keepAwakePending = false;
            keepAwakeError = message;
            lastError = settings.error;
        } else if (id.startsWith("power-suspend-")) {
            suspendPendingAction = "";
            suspendError = message;
            lastError = settings.error;
        } else {
            lastError = message;
        }
        settings.resume();
    }

    function transportFailed(message: string): void {
        transportError = message;
        powerSuspend = Object.assign({}, powerSuspend, {
            available: false
        });
        if (keepAwakePending) {
            keepAwakePending = false;
            keepAwakeError = "Connection lost; Keep awake state is unknown until reconnected. " + message;
        }
        if (suspendPolicySaving)
            suspendPolicyFailed("Connection lost; settings may have been saved. Retry to confirm. " + message);
        settings.stop();
        if (suspendPendingAction.length > 0) {
            suspendPendingAction = "";
            suspendError = "Connection lost. The request may already have been accepted; check the session before retrying. " + message;
            lastError = settings.error;
        } else if (actionInFlight) {
            // A recovered snapshot cannot confirm whether an effect succeeded.
            lastError = message;
        }
        actionInFlight = false;
        settings.transportFailed(message);
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

    function chargeOnce(): bool {
        if (actionInFlight || settings.thresholdOperationActive || batteryOperationActive || !protectionSupported || !battery.plugged || !selectedDevice)
            return false;
        return startOperation(backend.chargeOnce(selectedDevice.id));
    }

    function setChargingInhibited(enabled: bool): bool {
        if (actionInFlight || settings.thresholdOperationActive || !inhibitionSupported || !selectedDevice || (batteryOperationActive && !chargingInhibited))
            return false;
        return startOperation(backend.setChargingInhibited(selectedDevice.id, enabled));
    }

    function toggleCalibration(): bool {
        if (actionInFlight || settings.thresholdOperationActive || !calibrationSupported || !selectedDevice || (!calibrating && (!battery.plugged || batteryOperationActive)))
            return false;
        return startOperation(calibrating ? backend.cancelCalibration(selectedDevice.id) : backend.startCalibration(selectedDevice.id));
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
        if (!canSetKeepAwake || typeof enabled !== "boolean" || (enabled && (keepAwakeReleaseOnly || suspendBusy)))
            return false;
        keepAwakePending = true;
        keepAwakeError = "";
        actionInFlight = true;
        if (batteryBackend.setKeepAwake(enabled))
            return true;
        operationFailed("power-keep-awake-", keepAwakeError || "Unable to change Keep awake");
        return false;
    }

    function canPowerSuspendAction(action: string): bool {
        if (actionInFlight || suspendBusy || !powerSuspend.available || ["lock", "suspend", "hibernate"].indexOf(action) < 0)
            return false;
        if (action !== "lock" && keepAwake)
            return false;
        if (action === "suspend" && !Presentation.suspendCapabilityAvailable(powerSuspend.can_suspend))
            return false;
        if (action === "hibernate" && !Presentation.suspendCapabilityAvailable(powerSuspend.can_hibernate))
            return false;
        return true;
    }

    function powerSuspendAction(action: string): bool {
        if (!canPowerSuspendAction(action))
            return false;
        // Set state before sending: transport rejection can be synchronous.
        suspendPendingAction = action;
        suspendRetryAction = action;
        suspendError = "";
        lastError = settings.error;
        actionInFlight = true;
        if (backend.powerSuspendAction(action))
            return true;
        operationFailed("power-suspend-" + action, suspendError || "Unable to send the request");
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
        blocked: controller.actionInFlight || controller.settings.operationActive
        startMessage: "Capturing Battery & Power panel…"
    }

    BatterySettings {
        id: batterySettings
        backend: batteryBackend
        actionInFlight: controller.actionInFlight
        batteryOperationActive: controller.batteryOperationActive
        protectionSupported: controller.protectionSupported
        selectedDevice: controller.selectedDevice
        protection: controller.protection
        policy: controller.policy
        levelProfileOptions: controller.levelProfileOptions
        onStatusMessage: function (message) { controller.lastError = message; }
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
