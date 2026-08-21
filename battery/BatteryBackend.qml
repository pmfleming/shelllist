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

    function setProtection(enabled: bool): bool {
        return call(nextId("battery-protection"), BatteryApi.methods.setProtection, {
            enabled: enabled
        });
    }

    function chargeOnce(): bool {
        return call(nextId("battery-charge-once"), BatteryApi.methods.chargeOnce, {});
    }

    function setAlertPolicy(warningPercent: int, criticalPercent: int,
            notifyWhenFull: bool): bool {
        return call(nextId("battery-alerts"), BatteryApi.methods.setAlertPolicy, {
            warning_percent: warningPercent,
            critical_percent: criticalPercent,
            notify_when_full: notifyWhenFull
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
        if (data.battery)
            controller.applyBattery(data.battery);
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventReceived: function (event) { controller.handleEvent(event); }
    onSendFailed: function (_id, message) { controller.operationFailed(message); }
    onTransportFailed: function (message) { controller.operationFailed(message); }
    onTransportReady: snapshot()
}
