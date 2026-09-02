import QtQuick
import Shelllist.Io as Io
import "BatteryApi.js" as BatteryApi

Io.DaemonBackend {
    required property var controller
    daemonName: "bar-daemon"
    expectedProtocol: BatteryApi.protocol
    expectedVersion: BatteryApi.version
    streams: BatteryApi.subscribedStreams
    // Battery does not need a second permanent copy of the resident bar
    // subscription while its surface is hidden.
    active: controller.uiActive

    function snapshot(): bool {
        return callSequenced("battery-snapshot", BatteryApi.methods.snapshot, {});
    }

    function history(): bool {
        return callSequenced("battery-history", BatteryApi.methods.history, {});
    }

    function setThresholds(batteryId: string, startPercent: int, endPercent: int): bool {
        return callSequenced("battery-thresholds", BatteryApi.methods.setThresholds, {
            battery_id: batteryId,
            start_percent: startPercent,
            end_percent: endPercent
        });
    }

    function setProtection(batteryId: string, enabled: bool, startPercent: int,
            endPercent: int): bool {
        return callSequenced("battery-protection", BatteryApi.methods.setProtection, {
            battery_id: batteryId,
            enabled: enabled,
            start_percent: startPercent,
            end_percent: endPercent
        });
    }

    function chargeOnce(batteryId: string): bool {
        return callSequenced("battery-charge-once", BatteryApi.methods.chargeOnce, {
            battery_id: batteryId
        });
    }

    function setChargingInhibited(batteryId: string, enabled: bool): bool {
        return callSequenced("battery-inhibit", BatteryApi.methods.setChargingInhibited, {
            battery_id: batteryId,
            enabled: enabled
        });
    }

    function startCalibration(batteryId: string): bool {
        return callSequenced("battery-calibrate", BatteryApi.methods.startCalibration, {
            battery_id: batteryId
        });
    }

    function cancelCalibration(batteryId: string): bool {
        return callSequenced("battery-calibrate-cancel", BatteryApi.methods.cancelCalibration, {
            battery_id: batteryId
        });
    }

    function setPowerProfile(profile: string): bool {
        return callSequenced("power-profile", BatteryApi.methods.setPowerProfile, {
            profile: profile
        });
    }

    function setBatteryAware(enabled: bool): bool {
        return callSequenced("power-battery-aware", BatteryApi.methods.setBatteryAware, {
            enabled: enabled
        });
    }

    function setPowerActionEnabled(action: string, enabled: bool): bool {
        return callSequenced("power-action", BatteryApi.methods.setPowerActionEnabled, {
            action: action,
            enabled: enabled
        });
    }

    function powerSleepAction(action: string): bool {
        const method = action === "lock" ? BatteryApi.methods.lock
            : (action === "suspend" ? BatteryApi.methods.suspend
                : BatteryApi.methods.hibernate);
        return callSequenced("power-sleep-" + action, method, {});
    }

    function setAlertPolicy(warningPercent: int, criticalPercent: int,
            notifyWhenFull: bool, autoPowerSaver: bool): bool {
        return callSequenced("battery-alerts", BatteryApi.methods.setAlertPolicy, {
            warning_percent: warningPercent,
            critical_percent: criticalPercent,
            notify_when_full: notifyWhenFull,
            auto_power_saver: autoPowerSaver
        });
    }

    function isBackgroundRequest(id: string): bool {
        return id.startsWith("battery-snapshot-") || id.startsWith("battery-history-");
    }
    function settingsDomain(id: string): string {
        if (id.startsWith("battery-protection-") || id.startsWith("battery-thresholds-"))
            return "threshold";
        if (id.startsWith("battery-alerts-"))
            return "alert";
        return "";
    }
    function applyData(data: var): void {
        const values = Object.assign({}, data.snapshot || ({}), data);
        const handlers = ({
            battery: controller.applyBattery,
            power_profile: controller.applyPowerProfile,
            power_sleep: controller.applyPowerSleep,
            history: controller.applyBatteryHistory
        });
        Object.keys(handlers).forEach(function (key) {
            if (values[key])
                handlers[key](values[key]);
        });
    }
    function rejectRequest(id: string, background: bool, error: string): void {
        const domain = settingsDomain(id);
        if (background)
            controller.refreshFailed(id, error);
        else if (domain.length > 0)
            controller.settingsOperationFailed(domain, error);
        else
            controller.operationFailed(id, error);
    }
    function acceptRequest(id: string, background: bool): void {
        const domain = settingsDomain(id);
        if (background)
            controller.refreshFinished(id);
        else if (domain.length > 0)
            controller.settingsOperationFinished(domain);
        else
            controller.operationFinished(id);
    }
    function finish(id: string, envelope: var, transportError: string): void {
        const background = isBackgroundRequest(id);
        const error = responseError(envelope, transportError,
            background ? "Battery refresh failed" : "Battery operation failed");
        if (error.length > 0) {
            rejectRequest(id, background, error);
            return;
        }
        acceptRequest(id, background);
        applyData(envelope.data || ({}));
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventGapDetected: controller.refreshAll()
    onEventReceived: function (event) { controller.handleEvent(event); }
    onSendFailed: function (id, message) {
        if (isBackgroundRequest(id))
            controller.refreshFailed(id, message);
        else {
            const domain = settingsDomain(id);
            if (domain.length > 0)
                controller.settingsOperationFailed(domain, message);
            else
                controller.operationFailed(id, message);
        }
    }
    onTransportFailed: function (message) { controller.transportFailed(message); }
    onTransportReady: {
        snapshot();
        controller.resumePendingSettings();
    }
}
