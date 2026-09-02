import Quickshell
import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui
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
    property var powerProfile: ({ available: false, profile: "", profiles: [] })
    property var powerSleep: ({ available: false, inhibitors: [] })
    property var osdHardware: ({ available: false, caps_lock: false, num_lock: false,
        keyboard_backlight_percent: null, microphone_privacy: false, camera_privacy: false })
    property var notifications: ({ available: false, count: 0, dnd: false })
    property var notificationActive: ({ available: false, revision: 0, notifications: [] })
    property var updates: ({ available: false, ready: false, lanes: [] })
    property var timezone: ({ available: false, timezone: "", city: "", abbreviation: "", utc_offset_seconds: 0 })
    property bool osdVisible: false
    property var osd: ({
        kind: "", icon: "", label: "", valueLabel: "", percent: 0,
        progressVisible: false, timeoutMs: 1400
    })

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

    function applyDomainEvent(event: var): void {
        const stream = event.stream || "";
        const propertyName = BarApi.propertyByStream[stream] || "";
        const previous = propertyName.length > 0 ? controller[propertyName] : null;
        const value = event.data || ({});
        if (!applyDomain(stream, value)) {
            console.warn("shelllist bar event ignored stream=" + (stream || "unknown"));
            return;
        }
        if (event.event === "changed")
            presentDomainOsd(stream, previous, value);
    }

    function presentDomainOsd(stream: string, previous: var, value: var): void {
        const nextOsd = Presentation.domainOsd(
            BarApi.streams, stream, previous, value);
        if (nextOsd)
            presentOsd(nextOsd);
    }
    function handleEvent(event: var): void {
        const compatibility = Core.ApiEnvelope.compatibilityError(event,
            BarApi.protocol, BarApi.version, "bar-daemon");
        if (compatibility.length > 0) {
            console.warn("shelllist bar event rejected error=" + compatibility);
            return;
        }
        if (event.event === "lagged")
            backend.snapshot();
        else if (["subscribed", "changed"].includes(event.event))
            applyDomainEvent(event);
    }

    function openSurface(surfaceId: string): void {
        if (surfaceRegistry)
            surfaceRegistry.surfaceRequested(surfaceId);
    }
    function openNotificationCenter(): void {
        if (surfaceRegistry) {
            surfaceRegistry.ensureLoaded("activity");
            if (surfaceRegistry.activityController)
                surfaceRegistry.activityController.openSection("notifications");
        }
        openSurface("activity");
    }

    function focusWorkspace(workspaceId: int): bool { return backend.focusWorkspace(workspaceId); }
    function mediaOperation(operation: string): bool { return backend.mediaOperation(operation); }
    function cycleMediaPlayer(): bool {
        return (media.players || []).length > 1 && backend.mediaOperation("cycle");
    }
    function seekMedia(offsetSeconds: int): bool {
        return !!activePlayer && !!activePlayer.can_seek && backend.seekMedia(offsetSeconds);
    }
    function adjustAudio(deltaPercent: int): bool { return backend.adjustAudio(deltaPercent); }
    function toggleMuted(): bool { return backend.toggleMuted(); }
    function toggleInputMuted(): bool { return backend.toggleInputMuted(); }
    function adjustBrightness(deltaPercent: int): bool { return backend.adjustBrightness(deltaPercent); }
    function cyclePowerProfile(): bool {
        if (!powerProfile.available || backend.requestRunning)
            return false;
        const profile = Presentation.nextPowerProfile(powerProfile);
        return profile.length > 0 && backend.setPowerProfile(profile);
    }
    function dismissNotification(notificationId: int): bool {
        return backend.dismissNotification(notificationId);
    }
    function clearNotificationGroup(groupKey: string): bool {
        return backend.clearNotificationGroup(groupKey);
    }
    function snoozeNotification(notificationId: int, minutes: int): bool {
        return backend.snoozeNotification(notificationId, Date.now() + minutes * 60 * 1000);
    }
    function invokeNotificationAction(notificationId: int, actionKey: string): bool {
        return backend.invokeNotificationAction(notificationId, actionKey);
    }
    function replyNotification(notificationId: int, text: string): bool {
        return backend.replyNotification(notificationId, text);
    }
    function visibleToastGroups(monitorName: string): var {
        if (notifications.dnd)
            return [];
        const active = notificationActive && Array.isArray(notificationActive.notifications)
            ? notificationActive.notifications : [];
        const monitors = (workspaces.monitors || []).map(function (monitor) {
            return monitor.name;
        });
        const focused = workspaces.focused_monitor || "";
        const routed = active.filter(function (notification) {
            return Ui.NotificationPresentation.notificationMonitor(
                notification, focused, monitors) === monitorName;
        }).reverse();
        return Ui.NotificationPresentation.groupRecords(routed).slice(0, 3);
    }

    function presentOsd(descriptor: var): void {
        const value = Object.assign({
            kind: "", icon: "", label: "", valueLabel: "", percent: 0,
            progressVisible: false, timeoutMs: 1400
        }, descriptor);
        value.percent = Presentation.clamp(value.percent, 0, 100);
        value.progressVisible = !!value.progressVisible;
        value.timeoutMs = Math.max(400, Number(value.timeoutMs) || 1400);
        controller.osd = value;
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
            battery: function () { openSurface("battery"); },
            "power-profile-next": function () { cyclePowerProfile(); },
            activity: function () { openSurface("activity"); },
            notifications: function () { openNotificationCenter(); },
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
        interval: controller.osd.timeoutMs
        repeat: false
        onTriggered: controller.osdVisible = false
    }

    BarBackend { id: barBackend; controller: controller }
}
