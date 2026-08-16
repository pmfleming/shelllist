import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import "BarApi.js" as BarApi

Io.DaemonBackend {
    id: backend

    required property var controller
    daemonName: "bar-daemon"
    streams: BarApi.subscribedStreams
    active: true

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
        return call("audio-adjust", BarApi.methods.audioAdjust,
            { delta_percent: deltaPercent });
    }

    function toggleMuted(): bool {
        return call("audio-muted", BarApi.methods.audioSetMuted, { muted: null });
    }

    function adjustBrightness(deltaPercent: int): bool {
        return call("brightness-adjust", BarApi.methods.brightnessAdjust,
            { delta_percent: deltaPercent });
    }

    function setPowerProfile(profile: string): bool {
        return call("power-profile", BarApi.methods.powerProfileSet, { profile: profile });
    }

    function toggleNotifications(): bool {
        return call("notifications-panel", BarApi.methods.notificationsTogglePanel, {});
    }

    function toggleDnd(): bool {
        return call("notifications-dnd", BarApi.methods.notificationsToggleDnd, {});
    }

    function refreshUpdates(): bool {
        return call("updates-refresh", BarApi.methods.updatesRefresh, {});
    }

    function finish(id: string, envelope: var, transportError: string): void {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            BarApi.protocol, BarApi.version, daemonName, "Bar operation failed");
        if (error.length > 0) {
            console.error("shelllist bar request failed id=" + id + " error=" + error);
            controller.status = error;
            return;
        }
        controller.applyResponse(envelope.data || ({}));
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventReceived: function (event) { controller.handleEvent(event); }
    onSendFailed: function (id, message) { controller.status = message; }
    onTransportFailed: function (message) {
        controller.available = false;
        controller.status = message;
    }
    onTransportReady: snapshot()
}
