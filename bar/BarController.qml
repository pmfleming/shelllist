import Quickshell
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Wifi as Wifi
import Shelllist.Bluetooth as Bluetooth
import Shelllist.Activity as Activity
import "BarApi.js" as BarApi
import "BarIndicators.js" as Indicators
import "BarMediaPresentation.js" as MediaPresentation
import "BarOsdPresentation.js" as OsdPresentation
import "BarStatusPresentation.js" as StatusPresentation

Item {
    id: controller

    required property var surfaceRegistry
    property var activity: ({
            available: false,
            syncing: false,
            event_count: 0,
            incomplete_todo_count: 0,
            next_event: null,
            sources: [],
            world_clocks: []
        })
    property var workspaces: ({
            available: false,
            monitors: [],
            workspaces: []
        })
    property var media: ({
            available: false,
            active_player: "",
            players: []
        })
    property var audio: ({
            available: false,
            volume_percent: 0,
            muted: false,
            input_available: false,
            input_muted: false
        })
    property var brightness: ({
            available: false,
            percent: 0
        })
    property var displays: ({
            available: false,
            outputs: []
        })
    property var battery: ({
            available: false,
            percentage: 0
        })
    property var powerProfile: ({
            available: false,
            profile: "",
            profiles: []
        })
    property var powerSuspend: ({
            available: false,
            inhibitors: []
        })
    property var osdHardware: ({
            available: false,
            caps_lock: false,
            num_lock: false,
            keyboard_backlight_percent: null,
            microphone_privacy: false,
            camera_privacy: false
        })
    property var notifications: notificationState ? notificationState.notifications : ({
            available: false,
            count: 0,
            dnd: false
        })
    property var notificationActive: notificationState ? notificationState.notificationActive : ({
            available: false,
            revision: 0,
            notifications: []
        })
    property var updates: ({
            available: false,
            ready: false,
            lanes: []
        })
    property var timezone: ({
            available: false,
            timezone: "",
            city: "",
            abbreviation: "",
            utc_offset_seconds: 0
        })
    property bool osdVisible: false
    property var osd: ({
            kind: "",
            icon: "",
            label: "",
            valueLabel: "",
            percent: 0,
            progressVisible: false,
            timeoutMs: 1400
        })

    readonly property Wifi.WifiController wifiController: surfaceRegistry ? surfaceRegistry.wifiController : null
    readonly property Bluetooth.BluetoothController bluetoothController: surfaceRegistry ? surfaceRegistry.bluetoothController : null
    readonly property var networkStatus: wifiController ? wifiController.activeStatus : null
    readonly property var activePlayer: MediaPresentation.playerFor(media)
    readonly property string activePlayerId: activePlayer ? activePlayer.id : ""
    readonly property BarBackend backend: barBackend

    function applyPayload(data: var): void {
        Object.keys(BarApi.propertyByPayload).forEach(function (payloadName) {
            const propertyName = BarApi.propertyByPayload[payloadName];
            if (controller.notificationState && ["notifications", "notificationActive"].includes(propertyName))
                return; // The resident notification store owns these streams.
            if (data[payloadName] !== undefined)
                controller[propertyName] = data[payloadName];
        });
    }

    function applySnapshot(snapshot: var): void {
        if (snapshot)
            applyPayload(snapshot);
    }
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
        const nextOsd = OsdPresentation.domainOsd(BarApi.streams, stream, previous, value);
        if (nextOsd)
            presentOsd(nextOsd);
    }
    function handleEvent(event: var): void {
        if (["subscribed", "changed"].includes(event.event))
            applyDomainEvent(event);
    }

    function openSurface(surfaceId: string): void {
        if (surfaceRegistry)
            surfaceRegistry.surfaceRequested(surfaceId);
    }
    function openNotificationCenter(groupKey: string): void {
        if (surfaceRegistry)
            surfaceRegistry.openNotifications(groupKey || "", "active", "");
    }
    function openTimeWeather(tab: string): void {
        if (surfaceRegistry)
            surfaceRegistry.requestTimeWeatherTab(tab);
        openSurface("time-weather");
    }

    function focusWorkspace(workspaceId: int): bool {
        return backend.focusWorkspace(workspaceId);
    }
    function mediaOperation(operation: string): bool {
        return backend.mediaOperation(operation);
    }
    function seekMedia(offsetSeconds: int): bool {
        return !!activePlayer && !!activePlayer.can_seek && backend.seekMedia(offsetSeconds);
    }
    function adjustAudio(deltaPercent: int): bool {
        return backend.adjustAudio(deltaPercent);
    }
    function toggleMuted(): bool {
        return backend.toggleMuted();
    }
    function toggleInputMuted(): bool {
        return backend.toggleInputMuted();
    }
    function adjustBrightness(deltaPercent: int): bool {
        return backend.adjustBrightness(deltaPercent);
    }
    function cyclePowerProfile(): bool {
        if (!powerProfile.available || backend.requestRunning)
            return false;
        const profile = StatusPresentation.nextPowerProfile(powerProfile);
        return profile.length > 0 && backend.setPowerProfile(profile);
    }
    function dismissNotification(notificationId: int): bool {
        return notificationState ? notificationState.dismissNotification(notificationId) : backend.dismissNotification(notificationId);
    }
    function clearNotificationGroup(groupKey: string): bool {
        return notificationState ? notificationState.clearNotificationGroup(groupKey) : backend.clearNotificationGroup(groupKey);
    }
    function snoozeNotification(notificationId: int, minutes: int): bool {
        return notificationState ? notificationState.snoozeNotification(notificationId, minutes) : backend.snoozeNotification(notificationId, Date.now() + minutes * 60 * 1000);
    }
    function invokeNotificationAction(notificationId: int, actionKey: string): bool {
        return notificationState ? notificationState.invokeNotificationAction(notificationId, actionKey) : backend.invokeNotificationAction(notificationId, actionKey);
    }
    readonly property Activity.NotificationState notificationState: surfaceRegistry ? surfaceRegistry.notificationState : null
    function replyNotification(notificationId: var, text: string): bool {
        return notificationState ? notificationState.replyNotification(notificationId, text) : false;
    }
    function visibleToastGroups(monitorName: string): var {
        const active = notificationActive && Array.isArray(notificationActive.notifications) ? notificationActive.notifications : [];
        const monitors = (workspaces.monitors || []).map(function (monitor) {
            return monitor.name;
        });
        const focused = workspaces.focused_monitor || "";
        const routed = active.filter(function (notification) {
            return notification.toast_visible !== false && (!notifications.dnd || notification.dnd_bypass === true) && Ui.NotificationPresentation.notificationMonitor(notification, focused, monitors) === monitorName;
        }).reverse();
        return Ui.NotificationPresentation.groupRecords(routed).slice(0, 3);
    }

    function presentOsd(descriptor: var): void {
        const value = Object.assign({
            kind: "",
            icon: "",
            label: "",
            valueLabel: "",
            percent: 0,
            progressVisible: false,
            timeoutMs: 1400
        }, descriptor);
        value.percent = Indicators.percent(value.percent);
        value.progressVisible = !!value.progressVisible;
        value.timeoutMs = Math.max(400, Number(value.timeoutMs) || 1400);
        controller.osd = value;
        osdVisible = true;
        osdTimeout.restart();
    }

    function showOutputOsd(state: var): void {
        presentOsd(OsdPresentation.outputOsd(state));
    }

    function showInputOsd(state: var): void {
        presentOsd(OsdPresentation.inputOsd(state));
    }

    function showBrightnessOsd(state: var): void {
        presentOsd(OsdPresentation.brightnessOsd(state));
    }

    function showBrightnessErrorOsd(): void {
        presentOsd(OsdPresentation.brightnessErrorOsd());
    }

    function statusModules(now: date): var {
        return StatusPresentation.statusModules({
            network: networkStatus,
            bluetooth: bluetoothController,
            battery: battery,
            notifications: notifications,
            notificationActive: notificationActive,
            timezone: timezone
        }, now);
    }
    function triggerModuleAction(action: string): bool {
        if (["wifi", "bluetooth", "displays", "battery", "activity"].includes(action)) {
            openSurface(action);
            return true;
        }
        const actions = ({
                portal: function () {
                    if (wifiController)
                        wifiController.portal.launchManual("", true);
                },
                updates: function () {
                    Quickshell.execDetached(["ghostty", "-e", "bash", "-lc", "journalctl -u 'nixos-update-*.service' -u 'nixos-ai-tools-*.service' -n 150 --no-pager; read -r -p 'Press enter to close'"]);
                },
                "audio-mixer": function () {
                    Quickshell.execDetached(["pavucontrol"]);
                },
                "audio-mute": backend.toggleMuted,
                "audio-up": function () {
                    backend.adjustAudio(5);
                },
                "audio-down": function () {
                    backend.adjustAudio(-5);
                },
                "power-profile-next": cyclePowerProfile,
                notifications: function () {
                    openNotificationCenter("");
                },
                "notifications-dnd": backend.toggleDnd,
                "time-weather": function () {
                    openTimeWeather("time");
                }
            });
        const key = action === "timezone" ? "time-weather" : action;
        if (!Object.prototype.hasOwnProperty.call(actions, key))
            return false;
        actions[key]();
        return true;
    }

    Timer {
        id: osdTimeout
        interval: controller.osd.timeoutMs
        repeat: false
        onTriggered: controller.osdVisible = false
    }

    BarBackend {
        id: barBackend
        controller: controller
    }
}
