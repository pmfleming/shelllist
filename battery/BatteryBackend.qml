import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import "BatteryApi.js" as BatteryApi

Io.DaemonBackend {
    id: backend

    required property var controller
    daemonName: "bar-daemon"
    streams: BatteryApi.subscribedStreams
    active: true
    property int sequence: 0

    function nextId(prefix: string): string {
        sequence += 1;
        return prefix + "-" + sequence;
    }

    function snapshot(): bool {
        return call("battery-snapshot", BatteryApi.methods.snapshot, {});
    }

    function setThresholds(batteryId: string, startPercent: int, endPercent: int): bool {
        return call(nextId("battery-thresholds"), BatteryApi.methods.setThresholds, {
            battery_id: batteryId,
            start_percent: startPercent,
            end_percent: endPercent
        });
    }

    function setProtection(batteryId: string, enabled: bool): bool {
        return call(nextId("battery-protection"), BatteryApi.methods.setProtection, {
            battery_id: batteryId,
            enabled: enabled
        });
    }

    function chargeOnce(batteryId: string): bool {
        return call(nextId("battery-charge-once"), BatteryApi.methods.chargeOnce, {
            battery_id: batteryId
        });
    }

    function setChargingInhibited(batteryId: string, enabled: bool): bool {
        return call(nextId("battery-inhibit"), BatteryApi.methods.setChargingInhibited, {
            battery_id: batteryId,
            enabled: enabled
        });
    }

    function startCalibration(batteryId: string): bool {
        return call(nextId("battery-calibrate"), BatteryApi.methods.startCalibration, {
            battery_id: batteryId
        });
    }

    function cancelCalibration(batteryId: string): bool {
        return call(nextId("battery-calibrate-cancel"), BatteryApi.methods.cancelCalibration, {
            battery_id: batteryId
        });
    }

    function setPowerProfile(profile: string): bool {
        return call(nextId("power-profile"), BatteryApi.methods.setPowerProfile, {
            profile: profile
        });
    }

    function setBatteryAware(enabled: bool): bool {
        return call(nextId("power-battery-aware"), BatteryApi.methods.setBatteryAware, {
            enabled: enabled
        });
    }

    function setPowerActionEnabled(action: string, enabled: bool): bool {
        return call(nextId("power-action"), BatteryApi.methods.setPowerActionEnabled, {
            action: action,
            enabled: enabled
        });
    }

    function powerSleepAction(action: string): bool {
        const method = action === "lock" ? BatteryApi.methods.lock
            : (action === "suspend" ? BatteryApi.methods.suspend
                : BatteryApi.methods.hibernate);
        return call(nextId("power-sleep-" + action), method, {});
    }

    function setAlertPolicy(warningPercent: int, criticalPercent: int,
            notifyWhenFull: bool, autoPowerSaver: bool): bool {
        return call(nextId("battery-alerts"), BatteryApi.methods.setAlertPolicy, {
            warning_percent: warningPercent,
            critical_percent: criticalPercent,
            notify_when_full: notifyWhenFull,
            auto_power_saver: autoPowerSaver
        });
    }

    function finish(id: string, envelope: var, transportError: string): void {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            BatteryApi.protocol, BatteryApi.version, daemonName, "Battery operation failed");
        if (error.length > 0) {
            controller.operationFailed(error);
            return;
        }
        controller.operationFinished(id);
        const data = envelope.data || ({});
        if (data.snapshot && data.snapshot.battery)
            controller.applyBattery(data.snapshot.battery);
        if (data.snapshot && data.snapshot.power_profile)
            controller.applyPowerProfile(data.snapshot.power_profile);
        if (data.snapshot && data.snapshot.power_sleep)
            controller.applyPowerSleep(data.snapshot.power_sleep);
        if (data.battery)
            controller.applyBattery(data.battery);
        if (data.power_profile)
            controller.applyPowerProfile(data.power_profile);
        if (data.power_sleep)
            controller.applyPowerSleep(data.power_sleep);
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventReceived: function (event) { controller.handleEvent(event); }
    onSendFailed: function (_id, message) { controller.operationFailed(message); }
    onTransportFailed: function (message) { controller.operationFailed(message); }
    onTransportReady: snapshot()
}
