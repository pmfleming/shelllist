pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Ui as Ui
import Shelllist.Bar as Bar
import "../../shell" as Shell
import "../qml" as Tests

// Explicit review captures only. Real panel components, synthetic state, recording
// daemon transport. Never accept a prompt or invoke a destructive operation.
Tests.DaemonTestCase {
    id: tests
    name: "ConfirmationReview"
    when: windowShown
    visible: true
    width: 1100
    height: 780
    Component {
        id: factory
        Rectangle {
            id: panel
            width: tests.width; height: tests.height
            color: Ui.Theme.window
            property alias registry: registry
            property alias surface: loader.item
            Shell.SurfaceRegistry { id: registry; barController: desktop }
            Bar.BarController { id: desktop; surfaceRegistry: registry }
            Ui.SurfaceViewport {
                id: viewport
                anchors.fill: parent
                canvasWidth: registry.currentController ? registry.currentController.currentWindowWidth : width
                Loader {
                    id: loader
                    width: viewport.canvasWidth; height: viewport.canvasHeight
                    sourceComponent: registry.bundleFor(registry.currentId)?.content ?? null
                }
            }
        }
    }
    function init() {
        calls = [];
        Ui.Theme.previewColorScheme = Qt.Dark;
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "1", SHELLLIST_ACCENT: "#a6c8ff"};
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Unable to assign|Cannot assign).*/);
    }
    function cleanup() {
        Quickshell.environment = ({});
        Ui.Theme.previewColorScheme = Qt.Unknown;
    }
    function displayState() {
        return {available: true, baseline: "review-baseline", policy: {prefer_external: false}, status: "extended",
            layout: {saved: {outputs: []}, trial: null}, outputs: [
                {id: 0, name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, x: 0, y: 0, scale: 1.25, transform: 0, disabled: false, supported: true, internal: true, current_mode: "mode-1", modes: [{id: "mode-1", width: 1920, height: 1200, rate: 60, size: "1920x1200"}]}
            ]};
    }
    function seed(panel, id, scenario) {
        const c = panel.registry.controllerFor(id);
        if (id === "clipboard") {
            const entry = {id: "review-clip", revision: 1, kind: "text", favorite: false, preview: "Meeting notes", byte_size: 48};
            c.replaceProviderResults(c.provider.resultsForEntries([entry]), true);
            c.detailState.entryId = entry.id; c.detailState.entryRevision = 1;
            c.detailState.value = {entry: entry, text: "Synthetic meeting notes. No private clipboard data.", files: []};
        } else if (id === "bluetooth") {
            c.applySnapshot({radio: {available: true, operational: true, powered: true, adapter_count: 1},
                adapters: [{key: "adapter", alias: "Built-in adapter", powered: true}],
                devices: [{key: "buds", name: "Studio headphones", paired: true, connected: true, adapter_key: "adapter", battery: [], services: [], policy: {}, capabilities: {can_remove: true}}]});
        } else if (id === "wifi") {
            c.applyNetworks([{key: "review-wifi", ssid: "Home network", active: scenario === "wifi-disconnect-forget", strength: 90, security: "wpa2", frequency: 5180, profiles: [{id: "Home network"}]}], true, null);
        } else if (id === "battery") {
            c.applyBattery({available: true, percentage: 80, plugged: true, charging: true, power_available: true, power_watts: 8.4,
                devices: [{id: "BAT0", health_percent: 94, cycles: 186, protection: {supported: true, managed: true, enabled: true,
                    desired_enabled: true, desired_start_percent: 75, desired_end_percent: 80, start_percent: 75, end_percent: 80,
                    thresholds_verified: true, available_behaviours: ["inhibit-charge", "force-discharge"]}}]});
            c.applyPowerProfile({available: true, profile: "balanced", profiles: [{name: "balanced"}]});
            c.applyPowerSuspend({available: true, can_suspend: "yes", can_hibernate: "yes", keep_awake: false, lock_before_sleep: true, inhibitors: []});
        } else if (id === "notifications") {
            const message = {id: 101, app_key: "named:Mail", app_name: "Mail", app_icon: "", summary: "Meeting reminder", body: "Synthetic notification", created_unix_ms: Date.now()};
            c.notificationState.applySummary({available: true, backend: "native", count: 12, dnd: false, history_revision: 1, app_policies: {}});
            c.catalog.apps = [{key: "named:Mail", count: 12, total_count: 12, latest: message}];
            c.rebuildRecords();
        } else if (id === "displays") {
            c.applyDisplayPolicy(displayState());
        } else if (id === "applications") {
            c.replaceProviderResults(c.provider.resultsFor([{id: "review-app", kind: "desktop-application", name: "Android Studio (stable channel)", description: "The official Android IDE", running: false, running_count: 0, instances: [], desktop_actions: []}]), true);
        }
        c.availableScreenWidth = Qt.binding(() => panel.width);
        c.availableScreenHeight = Qt.binding(() => panel.height);
        c.uiActive = true;
        if (id !== "battery") {
            tryVerify(() => c.hasSelection);
            c.openDetails();
            tryVerify(() => panel.surface.detailsItem !== null);
        }
        return c;
    }
    function findModal(item) {
        if (item instanceof Ui.ModalFrame && item.visible) return item;
        for (const child of item.children) {
            const found = findModal(child);
            if (found) return found;
        }
        return null;
    }
    function save(item, name) {
        let saved = false;
        const directory = decodeURIComponent(Qt.resolvedUrl("../../target/confirmation-implementation/captures/").toString().replace(/^file:\/\//, ""));
        verify(item.grabToImage(result => { saved = result.saveToFile(directory + name + ".png"); }, Qt.size(Math.ceil(item.width), Math.ceil(item.height))));
        tryVerify(() => saved);
    }
    function test_capture_data() {
        return [
            {tag: "clipboard-single", panel: "clipboard"},
            {tag: "clipboard-bulk-one", panel: "clipboard"},
            {tag: "clipboard-bulk", panel: "clipboard"},
            {tag: "clipboard-wipe", panel: "clipboard"},
            {tag: "clipboard-menu", panel: "clipboard"},
            {tag: "notifications-one", panel: "notifications"},
            {tag: "notifications-app", panel: "notifications"},
            {tag: "notifications-all", panel: "notifications"},
            {tag: "bluetooth-forget", panel: "bluetooth"},
            ...["confirmation", "authorization", "service-authorization", "pin-code", "passkey", "display-pin", "display-passkey"].map(kind => ({tag: "bluetooth-" + kind, panel: "bluetooth", kind: kind})),
            {tag: "wifi-forget", panel: "wifi"},
            {tag: "wifi-disconnect-forget", panel: "wifi"},
            {tag: "battery-calibration", panel: "battery"},
            {tag: "battery-critical", panel: "battery"},
            {tag: "display-trial", panel: "displays"},
            {tag: "display-discard", panel: "displays"},
            {tag: "applications-empty", panel: "applications"}
        ];
    }
    function test_capture(data) {
        const panel = createTemporaryObject(factory, tests);
        panel.registry.select(data.panel);
        tryVerify(() => panel.registry.controllerFor(data.panel) !== null && panel.surface !== null);
        const c = seed(panel, data.panel, data.tag);
        if (data.tag === "clipboard-single") c.deleteConfirmationOpen = true;
        else if (data.tag.startsWith("clipboard-bulk")) {
            c.multiSelectedIds = data.tag.endsWith("one") ? {a: {id: "a", revision: 1}} : {a: {id: "a", revision: 1}, b: {id: "b", revision: 1}, c: {id: "c", revision: 1}};
            c.bulkDeleteConfirmationOpen = true;
        } else if (data.tag === "clipboard-wipe") c.wipeChallenge = {id: "synthetic-challenge"};
        else if (data.tag === "clipboard-menu") c.deleteMenuOpen = true;
        else if (data.panel === "notifications") {
            c.notificationState.deleteLabel = data.tag.endsWith("one") ? "Meeting reminder" : data.tag.endsWith("app") ? "Mail" : "All notifications";
            c.notificationState.deleteScope = {app_key: data.tag.endsWith("all") ? null : "named:Mail",
                selected: data.tag.endsWith("one") ? {id: 101, created: 101000} : null};
            c.notificationState.deleteConfirmation = {token: "synthetic-token", count: data.tag.endsWith("one") ? 1 : data.tag.endsWith("app") ? 12 : 47, expires_unix_ms: Date.now() + 60000};
        } else if (data.tag === "bluetooth-forget") {
            const action = c.provider.actionsForDevice(c.allDevices[0]).find(action => action.id === "forget");
            c.pendingConfirmationAction = action;
        } else if (data.panel === "bluetooth") {
            c.replacePairingPrompts([{request_id: "synthetic-pairing", kind: data.kind, device_key: "buds", response_required: !data.kind.startsWith("display-"), value: ["confirmation", "display-pin", "display-passkey"].includes(data.kind) ? "482019" : "", entered: 3, service: "Audio Sink (0000110b-0000-1000-8000-00805f9b34fb)"}]);
        } else if (data.panel === "wifi") {
            c.prompt.openForgetPrompt(c.selectedResult.payload, data.tag === "wifi-disconnect-forget", [{id: "Home network"}]);
        } else if (data.panel === "battery") {
            panel.surface.review(data.tag === "battery-critical" ? "critical" : "calibration");
        } else if (data.tag === "display-trial") {
            const state = displayState();
            state.layout.trial = {id: "synthetic-trial", expires_at: Date.now() / 1000 + 20};
            c.applyDisplayPolicy(state);
        } else if (data.tag === "display-discard") c.discardPrompt = true;
        for (const scheme of [Qt.Dark, Qt.Light]) {
            Ui.Theme.previewColorScheme = scheme;
            wait(250);
            verify(waitForPolish(panel.Window.window));
            const suffix = scheme === Qt.Light ? "-light" : "-dark";
            save(panel, data.tag + suffix + "-context");
            if (data.panel !== "applications") {
                const modal = findModal(panel);
                verify(modal !== null, data.tag + " must show the real modal");
                if (modal.compactPresentation) {
                    verify(!findChild(modal, "modalDetail").visible);
                    verify(!findChild(modal, "promptActionSummary").visible);
                }
                save(findChild(modal, "modalCard"), data.tag + suffix);
            }
        }
        verify(!calls.some(call => /\.(set|connect$|disconnect$|commit|invoke|preview|confirm|reply|dismiss|launch|activate|rename|delete|remove|respond)/.test(call.method)), "capture must not dispatch mutations");
    }
}
