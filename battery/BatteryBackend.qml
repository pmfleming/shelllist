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

    function setProtection(batteryId: string, enabled: bool, startPercent: int, endPercent: int): bool {
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

    function resumeAutomaticProfiles(): bool {
        return callSequenced("power-resume-automatic", BatteryApi.methods.resumeAutomaticProfiles, {});
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

    function powerSuspendAction(action: string): bool {
        const methods = {
            lock: BatteryApi.methods.lock,
            suspend: BatteryApi.methods.suspend,
            hibernate: BatteryApi.methods.hibernate
        };
        if (!["lock", "suspend", "hibernate"].includes(action))
            return false;
        return callSequenced("power-suspend-" + action, methods[action], {});
    }

    function setKeepAwake(enabled: bool): bool {
        return callSequenced("power-keep-awake", BatteryApi.methods.setKeepAwake, { enabled: enabled });
    }

    function setCriticalPolicy(policy: var): bool {
        return callSequenced("suspend-policy", BatteryApi.methods.setCriticalPolicy, policy);
    }

    function cancelCriticalBattery(): bool {
        return callSequenced("critical-battery-cancel", BatteryApi.methods.cancelCritical, {});
    }

    function setSuspendPolicy(policy: var): bool {
        return callSequenced("suspend-policy", BatteryApi.methods.setSuspendPolicy, policy);
    }

    function setAlertPolicy(policy: var): bool {
        return callSequenced("battery-alerts", BatteryApi.methods.setAlertPolicy, policy);
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
                power_sleep: controller.applyPowerSuspend,
                sleep_policy: controller.applySuspendPolicy,
                history: controller.applyBatteryHistory
            });
        Object.keys(handlers).forEach(function (key) {
            if (values[key])
                handlers[key](values[key]);
        });
    }
    function rejectRequest(id: string, background: bool, error: string): void {
        const domain = settingsDomain(id);
        if (id.startsWith("suspend-policy-"))
            controller.suspendPolicyFailed(error);
        else if (background)
            controller.refreshFailed(id, error);
        else if (domain.length > 0)
            controller.settingsOperationFailed(domain, error);
        else
            controller.operationFailed(id, error);
    }
    function acceptRequest(id: string, background: bool): void {
        const domain = settingsDomain(id);
        if (id.startsWith("suspend-policy-"))
            controller.suspendPolicyFinished();
        else if (background)
            controller.refreshFinished(id);
        else if (domain.length > 0)
            controller.settingsOperationFinished(domain);
        else
            controller.operationFinished(id);
    }
    function finish(id: string, envelope: var, transportError: string): void {
        const background = isBackgroundRequest(id);
        const error = responseError(envelope, transportError, background ? "Battery refresh failed" : "Battery operation failed");
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
    onEventReceived: function (event) {
        controller.handleEvent(event);
    }
    onSendFailed: function (id, message) {
        if (id.startsWith("suspend-policy-"))
            controller.suspendPolicyFailed(message);
        else if (isBackgroundRequest(id))
            controller.refreshFailed(id, message);
        else {
            const domain = settingsDomain(id);
            if (domain.length > 0)
                controller.settingsOperationFailed(domain, message);
            else
                controller.operationFailed(id, message);
        }
    }
    onTransportFailed: function (message) {
        controller.transportFailed(message);
    }
    onTransportReady: {
        snapshot();
        controller.resumePendingSettings();
    }
}
