import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import "BarApi.js" as BarApi

Io.DaemonBackend {
    required property var controller
    daemonName: "bar-daemon"
    streams: BarApi.subscribedStreams
    active: true
    property int operationSequence: 0

    function operationId(prefix: string): string {
        operationSequence += 1;
        return prefix + "-" + operationSequence;
    }

    function snapshot(): bool {
        return call("snapshot", BarApi.methods.snapshot, {});
    }

    function focusWorkspace(workspaceId: int): bool {
        return call("workspace-focus", BarApi.methods.workspaceFocus,
            { workspace_id: workspaceId, on_current_monitor: true });
    }

    function mediaOperation(operation: string): bool {
        return call("media-" + operation, BarApi.methods.mediaOperation,
            { operation: operation, player_id: controller.activePlayerId || null });
    }

    function adjustAudio(deltaPercent: int): bool {
        return call(operationId("audio-adjust"), BarApi.methods.audioAdjust,
            { delta_percent: deltaPercent });
    }

    function toggleMuted(): bool {
        return call(operationId("audio-muted"), BarApi.methods.audioSetMuted,
            { muted: null });
    }

    function toggleInputMuted(): bool {
        return call(operationId("audio-input-muted"),
            BarApi.methods.audioSetInputMuted, { muted: null });
    }

    function adjustBrightness(deltaPercent: int): bool {
        return call(operationId("brightness-adjust"),
            BarApi.methods.brightnessAdjust, { delta_percent: deltaPercent });
    }

    function toggleNotifications(): bool {
        return call("notifications-panel", BarApi.methods.notificationsTogglePanel, {});
    }

    function toggleDnd(): bool {
        return call("notifications-dnd", BarApi.methods.notificationsToggleDnd, {});
    }

    function finish(id: string, envelope: var, transportError: string): void {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            BarApi.protocol, BarApi.version, daemonName, "Bar operation failed");
        if (error.length > 0) {
            console.error("shelllist bar request failed id=" + id + " error=" + error);
            return;
        }
        const data = envelope.data || ({});
        controller.applyResponse(data);
        if (id.startsWith("audio-adjust-") || id.startsWith("audio-muted-"))
            controller.showOutputOsd(data.audio || controller.audio);
        else if (id.startsWith("audio-input-muted-"))
            controller.showInputOsd(data.audio || controller.audio);
        else if (id.startsWith("brightness-adjust-"))
            controller.showBrightnessOsd(data.brightness || controller.brightness);
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventReceived: function (event) { controller.handleEvent(event); }
    onSendFailed: function (id, message) {
        console.error("shelllist bar send failed id=" + id + " error=" + message);
    }
    onTransportFailed: function (message) {
        console.error("shelllist bar transport failed error=" + message);
    }
    onTransportReady: snapshot()
}
