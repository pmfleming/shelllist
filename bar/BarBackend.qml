import QtQuick
import Shelllist.Io as Io
import "BarApi.js" as BarApi

Io.DaemonBackend {
    required property var controller
    daemonName: "bar-daemon"
    expectedProtocol: BarApi.protocol
    expectedVersion: BarApi.version
    streams: BarApi.subscribedStreams
    active: true

    function operationId(prefix: string): string {
        return nextRequestId(prefix);
    }

    function snapshot(): bool {
        return call(operationId("snapshot"), BarApi.methods.snapshot, {});
    }

    function focusWorkspace(workspaceId: int): bool {
        return call(operationId("workspace-focus"), BarApi.methods.workspaceFocus,
            { workspace_id: workspaceId, on_current_monitor: true });
    }

    function mediaOperation(operation: string): bool {
        return call(operationId("media-" + operation), BarApi.methods.mediaOperation,
            { operation: operation, player_id: controller.activePlayerId || null });
    }

    function seekMedia(offsetSeconds: int): bool {
        return call(operationId("media-seek"), BarApi.methods.mediaOperation, {
            operation: "seek",
            player_id: controller.activePlayerId || null,
            offset_seconds: offsetSeconds
        });
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

    function setPowerProfile(profile: string): bool {
        return call(operationId("power-profile"),
            BarApi.methods.powerProfileSet, { profile: profile });
    }

    function toggleNotifications(): bool {
        return call(operationId("notifications-panel"),
            BarApi.methods.notificationsTogglePanel, {});
    }

    function toggleDnd(): bool {
        return call(operationId("notifications-dnd"),
            BarApi.methods.notificationsToggleDnd, {});
    }

    function dismissNotification(notificationId: int): bool {
        return call(operationId("notification-dismiss"),
            BarApi.methods.notificationsDismiss, { id: notificationId });
    }

    function clearNotificationGroup(groupKey: string): bool {
        return call(operationId("notifications-clear-group"),
            BarApi.methods.notificationsClearGroup, { group_key: groupKey });
    }

    function snoozeNotification(notificationId: int, untilUnixMs: double): bool {
        return call(operationId("notification-snooze"), BarApi.methods.notificationsSnooze, {
            id: notificationId,
            until_unix_ms: untilUnixMs
        });
    }

    function invokeNotificationAction(notificationId: int, actionKey: string): bool {
        return call(operationId("notification-action"),
            BarApi.methods.notificationsInvokeAction, {
                id: notificationId,
                action_key: actionKey,
                activation_token: null
            });
    }

    function replyNotification(notificationId: int, text: string): bool {
        return call(operationId("notification-reply"),
            BarApi.methods.notificationsReply, { id: notificationId, text: text });
    }

    function finish(id: string, envelope: var, transportError: string): void {
        const error = responseError(envelope, transportError,
            "Bar operation failed");
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
    onEventGapDetected: snapshot()
    onEventReceived: function (event) { controller.handleEvent(event); }
    onSendFailed: function (id, message) {
        console.error("shelllist bar send failed id=" + id + " error=" + message);
    }
    onTransportFailed: function (message) {
        console.error("shelllist bar transport failed error=" + message);
    }
    onTransportReady: snapshot()
}
