import Quickshell
import QtQuick
import Shelllist.Core as Core
import "BarApi.js" as BarApi
import "BarPresentation.js" as Presentation

Item {
    id: controller

    required property var surfaceRegistry
    property var activity: ({ available: false, syncing: false, event_count: 0,
        incomplete_todo_count: 0, next_event: null, sources: [], world_clocks: [] })
    property var workspaces: ({ available: false, monitors: [], workspaces: [] })
    property var media: ({ available: false, active_player: "", players: [] })
    property var audio: ({
        available: false,
        volume_percent: 0,
        muted: false,
        input_available: false,
        input_muted: false
    })
    property var brightness: ({ available: false, percent: 0 })
    property var battery: ({ available: false, percentage: 0 })
    property var powerProfile: ({ available: false, profile: "" })
    property var notifications: ({ available: false, count: 0, dnd: false })
    property var notificationActive: ({ available: false, revision: 0, notifications: [] })
    property var updates: ({ available: false, ready: false, lanes: [] })
    property var timezone: ({ available: false, timezone: "", city: "", abbreviation: "", utc_offset_seconds: 0 })
    property bool osdVisible: false
    property string osdKind: ""
    property string osdIcon: ""
    property string osdLabel: ""
    property string osdValueLabel: ""
    property int osdPercent: 0
    property bool osdProgressVisible: true

    readonly property var wifiController: surfaceRegistry ? surfaceRegistry.wifiController : null
    readonly property var bluetoothController: surfaceRegistry ? surfaceRegistry.bluetoothController : null
    readonly property var networkStatus: wifiController ? wifiController.activeStatus : null
    readonly property var activePlayer: Presentation.playerFor(media)
    readonly property string activePlayerId: activePlayer ? activePlayer.id : ""
    readonly property BarBackend backend: barBackend

    function applyPayload(data: var): void {
        Object.keys(BarApi.propertyByPayload).forEach(function (payloadName) {
            if (data[payloadName] !== undefined)
                controller[BarApi.propertyByPayload[payloadName]] = data[payloadName];
        });
    }

    function applySnapshot(snapshot: var): void { if (snapshot) applyPayload(snapshot); }
    function applyResponse(data: var): void {
        if (data.snapshot)
            applySnapshot(data.snapshot);
        applyPayload(data);
    }

    function applyDomain(stream: string, value: var): bool {
        const propertyName = BarApi.propertyByStream[stream] || "";
        if (propertyName.length === 0)
            return false;
        controller[propertyName] = value;
        return true;
    }

    function handleEvent(event: var): void {
        const compatibility = Core.ApiEnvelope.compatibilityError(event,
            BarApi.protocol, BarApi.version, "bar-daemon");
        if (compatibility.length > 0) {
            console.warn("shelllist bar event rejected error=" + compatibility);
            return;
        }
        if (event.event === "lagged") {
            backend.snapshot();
            return;
        }
        if ((event.event === "subscribed" || event.event === "changed")
                && !applyDomain(event.stream || "", event.data || ({})))
            console.warn("shelllist bar event ignored stream=" + (event.stream || "unknown"));
    }

    function openSurface(surfaceId: string): void {
        if (surfaceRegistry)
            surfaceRegistry.surfaceRequested(surfaceId);
    }

    function focusWorkspace(workspaceId: int): bool { return backend.focusWorkspace(workspaceId); }
    function mediaOperation(operation: string): bool { return backend.mediaOperation(operation); }
    function adjustAudio(deltaPercent: int): bool { return backend.adjustAudio(deltaPercent); }
    function toggleMuted(): bool { return backend.toggleMuted(); }
    function toggleInputMuted(): bool { return backend.toggleInputMuted(); }
    function adjustBrightness(deltaPercent: int): bool { return backend.adjustBrightness(deltaPercent); }
    function dismissNotification(notificationId: int): bool {
        return backend.dismissNotification(notificationId);
    }
    function invokeNotificationAction(notificationId: int, actionKey: string): bool {
        return backend.invokeNotificationAction(notificationId, actionKey);
    }
    function replyNotification(notificationId: int, text: string): bool {
        return backend.replyNotification(notificationId, text);
    }
    function visibleToasts(): var {
        if (notifications.dnd)
            return [];
        const active = notificationActive && Array.isArray(notificationActive.notifications)
            ? notificationActive.notifications : [];
        return active.slice(Math.max(0, active.length - 3)).reverse();
    }

    function presentOsd(osd: var): void {
        osdKind = osd.kind || "";
        osdIcon = osd.icon || "";
        osdLabel = osd.label || "";
        osdValueLabel = osd.valueLabel || "";
        osdPercent = Math.max(0, Math.min(100, Number(osd.percent) || 0));
        osdProgressVisible = !!osd.progressVisible;
        osdVisible = true;
        osdTimeout.restart();
    }

    function showOutputOsd(state: var): void {
        presentOsd(Presentation.outputOsd(state));
    }

    function showInputOsd(state: var): void {
        presentOsd(Presentation.inputOsd(state));
    }

    function showBrightnessOsd(state: var): void {
        presentOsd(Presentation.brightnessOsd(state));
    }

    function statusModules(now: date): var {
        return Presentation.statusModules({
            activity: activity, network: networkStatus, bluetooth: bluetoothController,
            updates: updates, audio: audio, brightness: brightness, battery: battery,
            powerProfile: powerProfile, notifications: notifications, timezone: timezone
        }, now);
    }
    function triggerModuleAction(action: string): bool {
        const actions = ({
            wifi: function () { openSurface("wifi"); },
            portal: function () { Quickshell.execDetached(["shelllist-captive-portal", "--manual", "--fallback"]); },
            updates: function () { Quickshell.execDetached(["ghostty", "-e", "bash", "-lc", "journalctl -u nixos-update-fast.service -u nixos-update-delayed.service -u delayed-nixos-update.service -n 100 --no-pager; read -r -p 'Press enter to close'"]); },
            bluetooth: function () { openSurface("bluetooth"); },
            "audio-mixer": function () { Quickshell.execDetached(["pavucontrol"]); },
            "audio-mute": function () { backend.toggleMuted(); },
            "audio-up": function () { backend.adjustAudio(5); },
            "audio-down": function () { backend.adjustAudio(-5); },
            "brightness-up": function () { backend.adjustBrightness(5); },
            "brightness-down": function () { backend.adjustBrightness(-5); },
            activity: function () { openSurface("activity"); },
            notifications: function () { openSurface("activity"); },
            "notifications-dnd": function () { backend.toggleDnd(); },
            timezone: function () { openSurface("activity"); }
        });
        const handler = actions[action];
        if (!handler)
            return false;
        handler();
        return true;
    }

    Timer {
        id: osdTimeout
        interval: 1400
        repeat: false
        onTriggered: controller.osdVisible = false
    }

    BarBackend { id: barBackend; controller: controller }
}
