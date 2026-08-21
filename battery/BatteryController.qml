import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui
import "BatteryApi.js" as BatteryApi
import "BatteryPresentation.js" as Presentation

Ui.ChooserController {
    id: controller

    property var battery: ({ available: false, percentage: 0, devices: [],
        policy: ({ warning_percent: 25, critical_percent: 12, notify_when_full: true }),
        protection: ({ supported: false, managed: false, enabled: false,
            desired_enabled: false, desired_start_percent: 75,
            desired_end_percent: 80, charge_once_active: false }) })
    property string lastError: ""
    property int draftStartPercent: 75
    property int draftEndPercent: 80
    property int draftWarningPercent: 25
    property int draftCriticalPercent: 12
    property bool draftNotifyWhenFull: true
    property bool thresholdDraftDirty: false
    property bool alertDraftDirty: false

    detailsOpen: false
    navigationPrimaryEnabled: false
    readonly property BatteryBackend backend: batteryBackend
    readonly property var protection: battery.protection || ({})
    readonly property var policy: battery.policy || ({})
    readonly property var primaryDevice: battery.devices && battery.devices.length > 0
        ? battery.devices[0] : null
    readonly property bool protectionSupported: !!protection.supported
    readonly property bool thresholdDraftValid: Presentation.thresholdRangeValid(
        draftStartPercent, draftEndPercent)
    readonly property bool alertDraftValid: Presentation.alertRangeValid(
        draftWarningPercent, draftCriticalPercent)

    function valueOr(value: var, fallback: var): var {
        return value === null || value === undefined ? fallback : value;
    }

    function applyBattery(value: var): void {
        battery = value || ({ available: false, percentage: 0, devices: [] });
        if (!thresholdDraftDirty) {
            draftStartPercent = Number(valueOr(protection.desired_start_percent, 75));
            draftEndPercent = Number(valueOr(protection.desired_end_percent, 80));
        }
        if (!alertDraftDirty) {
            draftWarningPercent = Number(valueOr(policy.warning_percent, 25));
            draftCriticalPercent = Number(valueOr(policy.critical_percent, 12));
            draftNotifyWhenFull = valueOr(policy.notify_when_full, true);
        }
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

    function setProtection(enabled: bool): bool {
        if (actionInFlight || !protectionSupported)
            return false;
        return startOperation(backend.setProtection(enabled));
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
        return startOperation(backend.chargeOnce());
    }

    function applyAlertPolicy(): bool {
        if (actionInFlight || !alertDraftValid)
            return false;
        return startOperation(backend.setAlertPolicy(draftWarningPercent,
            draftCriticalPercent, draftNotifyWhenFull));
    }

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
        backend.snapshot();
    }

    BatteryBackend { id: batteryBackend; controller: controller }
}
