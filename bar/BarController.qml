import Quickshell
import QtQuick
import Shelllist.Core as Core
import "BarApi.js" as BarApi
import "BarPresentation.js" as Presentation

Item {
    id: controller

    required property var surfaceRegistry
    property bool available
    property string status: "Starting bar-daemon…"
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

    function applySnapshot(snapshot: var): void {
        if (!snapshot)
            return;
        workspaces = snapshot.workspaces || workspaces;
        media = snapshot.media || media;
        audio = snapshot.audio || audio;
        brightness = snapshot.brightness || brightness;
        battery = snapshot.battery || battery;
        powerProfile = snapshot.power_profile || powerProfile;
        notifications = snapshot.notifications || notifications;
        updates = snapshot.updates || updates;
        timezone = snapshot.timezone || timezone;
        available = true;
        status = "";
    }

    function applyResponse(data: var): void {
        if (data.snapshot)
            applySnapshot(data.snapshot);
        if (data.audio)
            audio = data.audio;
        if (data.brightness)
            brightness = data.brightness;
        if (data.power_profile)
            powerProfile = data.power_profile;
        if (data.updates)
            updates = data.updates;
    }

    function applyDomain(stream: string, value: var): bool {
        if (stream === BarApi.streams.workspaces)
            workspaces = value;
        else if (stream === BarApi.streams.media)
            media = value;
        else if (stream === BarApi.streams.audio)
            audio = value;
        else if (stream === BarApi.streams.brightness)
            brightness = value;
        else if (stream === BarApi.streams.battery)
            battery = value;
        else if (stream === BarApi.streams.powerProfile)
            powerProfile = value;
        else if (stream === BarApi.streams.notifications)
            notifications = value;
        else if (stream === BarApi.streams.updates)
            updates = value;
        else if (stream === BarApi.streams.timezone)
            timezone = value;
        else
            return false;
        available = true;
        status = "";
        return true;
    }

    function handleEvent(event: var): void {
        const compatibility = Core.ApiEnvelope.compatibilityError(event,
            BarApi.protocol, BarApi.version, "bar-daemon");
        if (compatibility.length > 0) {
            status = compatibility;
            return;
        }
        if (event.event === "lagged") {
            status = "Bar events were missed; recovering current state…";
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
    function adjustBrightness(deltaPercent: int): bool { return backend.adjustBrightness(deltaPercent); }
    function toggleNotifications(): bool { return backend.toggleNotifications(); }
    function toggleDnd(): bool { return backend.toggleDnd(); }
    function openWifi(): void { openSurface("wifi"); }
    function openBluetooth(): void { openSurface("bluetooth"); }
    function openPortalFallback(): void {
        Quickshell.execDetached(["shelllist-captive-portal", "--manual", "--fallback"]);
    }
    function openAudioMixer(): void { Quickshell.execDetached(["pavucontrol"]); }
    function openUpdateJournal(): void {
        Quickshell.execDetached(["ghostty", "-e", "bash", "-lc",
            "journalctl -u nixos-update-fast.service -u nixos-update-delayed.service -u delayed-nixos-update.service -n 100 --no-pager; read -r -p 'Press enter to close'"]);
    }
    function openTimezoneDetails(): void {
        Quickshell.execDetached(["ghostty", "-e", "bash", "-lc",
            "timedatectl; read -r -p 'Press enter to close'"]);
    }

    BarBackend { id: barBackend; controller: controller }
}
