import Quickshell
import QtQuick
import Shelllist.Core as Core
import "BarApi.js" as BarApi
import "BarPresentation.js" as Presentation

Item {
    id: controller

    required property var surfaceRegistry
    property var workspaces: ({ available: false, monitors: [], workspaces: [] })
    property var media: ({ available: false, active_player: "", players: [] })
    property var audio: ({ available: false, volume_percent: 0, muted: false })
    property var brightness: ({ available: false, percent: 0 })
    property var battery: ({ available: false, percentage: 0 })
    property var powerProfile: ({ available: false, profile: "" })
    property var notifications: ({ available: false, count: 0, dnd: false })
    property var updates: ({ available: false, ready: false, lanes: [] })
    property var timezone: ({ available: false, timezone: "", city: "", abbreviation: "", utc_offset_seconds: 0 })

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
    function statusModules(now: date): var {
        return Presentation.statusModules({
            network: networkStatus, bluetooth: bluetoothController, updates: updates,
            audio: audio, brightness: brightness, battery: battery,
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
            notifications: function () { backend.toggleNotifications(); },
            "notifications-dnd": function () { backend.toggleDnd(); },
            timezone: function () { Quickshell.execDetached(["ghostty", "-e", "bash", "-lc", "timedatectl; read -r -p 'Press enter to close'"]); }
        });
        const handler = actions[action];
        if (!handler)
            return false;
        handler();
        return true;
    }

    BarBackend { id: barBackend; controller: controller }
}
