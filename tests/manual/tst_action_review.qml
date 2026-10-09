pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Ui as Ui
import Shelllist.Bar as Bar
import "../../shell" as Shell
import "../qml" as Tests
import "../qml/imports/Quickshell/Services/SystemTray" as Tray

// Explicit visual review of the actual 12 registered surfaces, using synthetic
// snapshots and recording transports only. No live services or compositor.
Tests.DaemonTestCase {
    id: tests
    name: "CircularActionReview"
    when: windowShown
    visible: true
    width: 1100
    height: 780
    Component {
        id: factory
        Rectangle {
            id: panel
            width: tests.width
            height: tests.height
            color: Ui.Theme.window
            property alias registry: registry
            property alias desktop: desktop
            property alias surface: content.item
            Shell.SurfaceRegistry { id: registry; barController: desktop }
            Bar.BarController { id: desktop; surfaceRegistry: registry }
            Ui.SurfaceViewport {
                id: viewport
                anchors.fill: parent
                canvasWidth: registry.currentController ? registry.currentController.currentWindowWidth : width
                Loader {
                    id: content
                    width: viewport.canvasWidth
                    height: viewport.canvasHeight
                    sourceComponent: registry.bundleFor(registry.currentId)?.content ?? null
                }
            }
        }
    }
    Component { id: trayFactory; Tray.SystemTrayItem { title: "Review application"; hasMenu: true; menu: QtObject {} } }
    Component {
        id: toastFactory
        Bar.NotificationToastCard {
            controller: Bar.BarController { surfaceRegistry: null }
            notification: ({id: 1, summary: "A long notification title with application actions", app_name: "Mail", body: "A synthetic toast; commands do not run during capture.", created_unix_ms: Date.now(), actions: [{key: "default", label: "Open"}, {key: "archive", label: "Archive conversation"}, {key: "inline-reply", label: "Reply"}]})
        }
    }
    Component {
        id: barFactory
        Bar.BarContent {
            width: 1000; height: 52; screenName: "review"
            controller: Bar.BarController { surfaceRegistry: null }
        }
    }
    Component {
        id: promptFactory
        Ui.PromptDialog {
            width: 700; height: 430
            title: "Delete this item?"
            detail: "Delete the synthetic clipboard item permanently. This cannot be undone."
            inputVisible: false
            actionsVisible: true
            acceptTone: "danger"
            acceptLabel: "Delete item"
            onAccepted: tests.fail("Captures must not accept prompts")
        }
    }
    function init() {
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Unable to assign|Cannot assign).*/);
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "1", SHELLLIST_ACCENT: "#6750a4"};
        calls = [];
    }
    function cleanup() {
        Tray.SystemTray.items.values = [];
        Quickshell.environment = ({});
        Ui.Theme.previewColorScheme = Qt.Unknown;
    }
    function seed(panel, id) {
        const c = panel.registry.controllerFor(id);
        if (id === "applications") {
            c.replaceProviderResults(c.provider.resultsFor([{id: "review-app", kind: "desktop-application", name: "Application with a very long translated display name", running: true, running_count: 1, instances: [], desktop_actions: [{name: "Open a private window"}]}]), true);
        } else if (id === "wifi") {
            c.applyNetworks([{key: "review-wifi", ssid: "rembrandtweg — a deliberately long network title", active: true, strength: 90, security: "wpa2", frequency: 5180, profiles: []}], true, null);
        } else if (id === "bluetooth") {
            c.applySnapshot({radio: {available: true, operational: true, powered: true, adapter_count: 1}, adapters: [{key: "adapter", alias: "Built-in adapter", powered: true}], devices: [{key: "buds", name: "Studio headphones with a long device name", paired: true, connected: true, adapter_key: "adapter", battery: [], services: [], policy: {}, capabilities: {can_rename: true}}]});
        } else if (id === "clipboard") {
            const entry = {id: "review-clip", revision: 1, kind: "text", favorite: false, preview: "Clipboard content with a deliberately long title to demonstrate separation", byte_size: 98};
            c.replaceProviderResults(c.provider.resultsForEntries([entry]), true);
            c.detailState.entryId = entry.id;
            c.detailState.entryRevision = 1;
            c.detailState.value = {entry: entry, text: "A synthetic clipboard example. Nothing will be pasted or copied.", files: []};
        } else if (id === "displays") {
            c.applyDisplayPolicy({available: true, policy: {prefer_external: false}, status: "extended", layout: {saved: {outputs: []}, trial: null}, outputs: [
                {id: 0, name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, x: 0, y: 0, scale: 1.25, transform: 0, disabled: false, supported: true, internal: true, current_mode: "mode-1", modes: [{id: "mode-1", width: 1920, height: 1200, rate: 60, size: "1920x1200"}]}
            ]});
        } else if (id === "battery") {
            c.applyBattery({available: true, percentage: 80, plugged: true, charging: true, power_available: true, power_watts: 8.4,
                devices: [{id: "BAT0", health_percent: 94, cycles: 186, protection: {supported: true, managed: true, enabled: true,
                    desired_enabled: true, desired_start_percent: 75, desired_end_percent: 80, start_percent: 75, end_percent: 80,
                    thresholds_verified: true, available_behaviours: ["inhibit-charge", "force-discharge"]}}]});
            c.applyPowerProfile({available: true, profile: "balanced", profiles: [{name: "power-saver"}, {name: "balanced"}, {name: "performance"}]});
            c.applyPowerSuspend({available: true, can_suspend: "yes", can_hibernate: "yes", keep_awake: false, lock_before_sleep: true, inhibitors: []});
            c.selectViewTab("power");
        } else if (id === "activity" || id === "time-weather") {
            const weather = {available: true, location: "Amsterdam", temperature_c: 18, high_c: 20, low_c: 12,
                condition: "Partly cloudy", condition_code: 2, utc_offset_seconds: 7200, updated_unix_ms: Date.now(), hourly: [], daily: []};
            c.applySnapshot({timezone: {available: true, timezone: "Europe/Amsterdam", city: "Amsterdam", abbreviation: "CEST", utc_offset_seconds: 7200},
                activity: {available: true, syncing: false, event_count: 0, incomplete_todo_count: 0, sources: [], world_clocks: [], weather_locations: [], weather: weather,
                    locations: [{id: "native-amsterdam", label: "Amsterdam", city: "Amsterdam", timezone: "Europe/Amsterdam", abbreviation: "CEST",
                        utc_offset_seconds: 7200, timezone_region_ids: [], has_coordinates: false, home: true, has_weather: true, weather: weather, lunar: null}]}});
        } else if (id === "notifications") {
            const message = {id: 101, app_key: "named:Mail", app_name: "Mail", app_icon: "", summary: "Notification with a deliberately long summary to check title elision", body: "Synthetic native-catalog preview. No sender actions in the center.", created_unix_ms: Date.now()};
            c.notificationState.applySummary({available: true, backend: "native", count: 1, dnd: false, history_revision: 1, app_policies: {}});
            c.catalog.apps = [{key: "named:Mail", count: 1, total_count: 1, latest: message}];
            c.rebuildRecords();
        } else if (id === "audio") {
            panel.desktop.audio = {available: true, sink_name: "speakers", sink_description: "Studio speakers", volume_percent: 50, muted: false};
        } else if (id === "media") {
            panel.desktop.media = {available: true, active_player: "player", players: [{id: "player", identity: "Music player with a long application name", title: "A very long track title", artist: "Artist", playback_status: "Playing", can_control: true, can_pause: true, can_play: true, can_previous: true, can_next: true, can_seek: true}]};
        } else if (id === "tray") {
            Tray.SystemTray.items.values = [createTemporaryObject(trayFactory, tests, {id: "review-tray"})];
        }
        c.availableScreenWidth = Qt.binding(() => panel.width);
        c.availableScreenHeight = Qt.binding(() => panel.height);
        c.uiActive = true;
        if (["audio", "media", "tray"].includes(id)) c.refresh();
        if (id !== "activity" && id !== "battery") {
            tryVerify(() => c.hasSelection, 5000, id + " must have a real selected result");
            c.openDetails();
            tryVerify(() => panel.surface.detailsItem !== null);
            if (id === "notifications") {
                c.timeline.busy = false;
                c.timeline.snapshot = {recent: [c.catalog.apps[0].latest], dates: [], next_offset: null};
            }
        }
    }
    function save(panel, name) {
        wait(180);
        verify(waitForPolish(panel.Window.window));
        const directory = Quickshell.env("SHELLLIST_REVIEW_DIR") || decodeURIComponent(Qt.resolvedUrl("../../target/circular-action-review/").toString().replace(/^file:\/\//, ""));
        // QtTest.grabImage crops using logical coordinates on HiDPI windows.
        // Grab the complete render layer instead; Qt applies the window DPR
        // to this logical target size (do not multiply by DPR a second time).
        let saved = false;
        verify(panel.grabToImage(function(result) {
            saved = result.saveToFile(directory + name + ".png");
        }, Qt.size(Math.ceil(panel.width), Math.ceil(panel.height))));
        tryVerify(() => saved);
    }
    function checkCircles(item) {
        if (!item.visible) return;
        if (item instanceof Ui.ActionButton) {
            compare(item.width, item.height, item.objectName + " must be square");
            compare(item.radius, item.width / 2);
            compare(findChild(item, "actionLabel").label, "");
            verify(item.icon.length > 0, item.objectName + " needs an icon");
        }
        for (const child of item.children) checkCircles(child);
    }
    function test_auxiliary_data() {
        return [{tag: "light", scheme: Qt.Light}, {tag: "dark", scheme: Qt.Dark}];
    }
    function test_auxiliary(data) {
        Ui.Theme.previewColorScheme = data.scheme;
        const toast = createTemporaryObject(toastFactory, tests);
        save(toast, "toast-" + data.tag);
        checkCircles(toast);
        toast.visible = false;
        const bar = createTemporaryObject(barFactory, tests);
        save(bar, "bar-" + data.tag);
        // The bar intentionally has its own compact artwork/shape grammar.
        // Panel circle assertions do not apply to BarAction or media artwork.
        bar.visible = false;
        const prompt = createTemporaryObject(promptFactory, tests);
        save(prompt, "prompt-" + data.tag);
        checkCircles(prompt);
    }
    function test_panels_data() {
        const rows = [];
        for (const id of ["applications", "wifi", "bluetooth", "clipboard", "displays", "audio", "media", "tray", "activity", "time-weather", "battery", "notifications"])
            for (const scheme of [Qt.Light, Qt.Dark]) rows.push({tag: id + (scheme === Qt.Light ? "-light" : "-dark"), id: id, scheme: scheme});
        return rows;
    }
    function test_panels(data) {
        Ui.Theme.previewColorScheme = data.scheme;
        const panel = createTemporaryObject(factory, tests);
        panel.registry.select(data.id);
        tryVerify(() => panel.registry.controllerFor(data.id) !== null && panel.surface !== null);
        seed(panel, data.id);
        save(panel, data.tag);
        checkCircles(panel.surface);
        panel.width = 976;
        panel.height = 600;
        save(panel, data.tag + "-minimum");
        verify(panel.surface.width <= panel.width, "supported minimum must fit the actual canvas");
        checkCircles(panel.surface);
        panel.width = tests.width;
        panel.height = tests.height;
        const controller = panel.registry.controllerFor(data.id);
        if (data.id === "activity") {
            controller.openSection("schedule");
            save(panel, data.tag + "-schedule");
            checkCircles(panel.surface);
        } else if (data.id === "notifications") {
            controller.openSettings();
            save(panel, data.tag + "-settings");
            checkCircles(panel.surface);
        } else if (data.id === "bluetooth") {
            controller.detailsTab = "settings";
            save(panel, data.tag + "-settings");
            checkCircles(panel.surface);
        }
        const tabs = ({applications: ["application", "resources", "settings"], bluetooth: ["device", "settings", "information"],
            clipboard: ["data", "info"], displays: ["settings", "information"], "time-weather": ["time", "weather"],
            notifications: ["notifications", "controls"]})[data.id] || [];
        if (data.id === "notifications") controller.settingsOpen = false;
        for (const tab of tabs) {
            controller.detailsTab = tab;
            save(panel, data.tag + "-" + tab);
        }
        if (data.id === "battery") {
            for (const tab of ["overview", "care", "power"]) {
                controller.selectViewTab(tab);
                save(panel, data.tag + "-" + tab);
            }
        }
        if (data.id === "bluetooth") {
            controller.openBluetoothSettings();
            for (const tab of ["general", "pairing"]) {
                controller.adapterSettingsTab = tab;
                save(panel, data.tag + "-adapter-" + tab);
            }
        }
        verify(!calls.some(call => /\.(set|connect$|disconnect$|commit|invoke|preview|confirm|reply|dismiss|launch|activate|rename)/.test(call.method)), "captures never dispatch mutations");
    }
}
