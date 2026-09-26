import QtQuick
import Shelllist.Io as Io
import "DisplayApi.js" as Api

Io.DaemonBackend {
    required property var controller
    daemonName: "bar-daemon"
    expectedProtocol: Api.protocol
    expectedVersion: Api.version
    streams: Api.subscribedStreams
    active: controller.uiActive || controller.actionInFlight || !!controller.trial

    function snapshot(): bool {
        return callSequenced("display-snapshot", Api.methods.snapshot, {});
    }
    function mutate(action: string, params: var): bool {
        return !!Api.methods[action] && callSequenced("display-" + action, Api.methods[action], params);
    }
    function applyData(data: var): void {
        const value = data.display_policy || (data.snapshot || {}).display_policy;
        if (value)
            controller.applyDisplayPolicy(value);
    }
    function finish(id: string, envelope: var, transportError: string): void {
        const message = responseError(envelope, transportError, "Display request failed");
        if (message.length > 0) {
            controller.requestFailed(id, message);
            return;
        }
        // Apply authoritative state before releasing pending-operation guards.
        applyData(envelope.data || {});
        controller.requestFinished(id);
    }
    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventReceived: function (event) {
        if (event.stream === Api.stream && ["changed", "subscribed"].includes(event.event))
            controller.applyDisplayPolicy(event.data || {});
    }
    onEventGapDetected: controller.refresh()
    onSendFailed: function (id, message) {
        controller.requestFailed(id, message);
    }
    onTransportFailed: function (message) {
        controller.transportFailed(message);
    }
    onTransportReady: snapshot()
}
