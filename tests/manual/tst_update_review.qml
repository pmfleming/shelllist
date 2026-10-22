pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "../../bar/BarProtocol.generated.js" as Contract
import "../qml" as Tests

// Actual native panel, synthetic observations and recording transports only.
Tests.DaemonTestCase {
    id: testCase
    name: "UpdatePanelReview"
    when: windowShown
    visible: true
    width: 1100
    height: 800
    Component {
        id: factory
        Rectangle {
            id: panel
            width: 1040; height: 720
            color: Ui.Theme.window
            property alias controller: controller
            property alias content: content
            Bar.BarController {
                id: state
                surfaceRegistry: null
                updates: ({available: true, error: null, jobs: [], lanes: [{name: "delayed", ready: true, revision: "9ba7c24", base_hash: "base-hash", created_at: 1792575600, auto_apply: false, system: "/nix/store/0123456789abcdef-nixos-system-host-26.05.328"}]})
            }
            Bar.UpdateController {
                id: controller
                barController: state
                availableScreenWidth: panel.width + 2 * Ui.Theme.spacingSm
                availableScreenHeight: panel.height + 2 * Ui.Theme.spacingSm
            }
            Ui.SurfaceViewport {
                id: viewport
                anchors.fill: parent
                canvasWidth: controller.currentWindowWidth
                Bar.UpdateContent {
                    id: content
                    width: viewport.canvasWidth
                    height: viewport.canvasHeight
                    controller: controller
                }
            }
        }
    }
    function init(): void {
        calls = [];
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Unable to assign|Cannot assign).*/);
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "1", SHELLLIST_ACCENT: "#6750a4"};
    }
    function cleanup(): void {
        Ui.Theme.previewColorScheme = Qt.Unknown;
        Quickshell.environment = ({});
        verify(calls.every(call => ["bar.snapshot", "updates.queryHistory", "updates.getOverview", "updates.readLog"].includes(call.method)));
    }
    function respond(method, data): void {
        const request = calls.filter(call => call.method === method).slice(-1)[0];
        verify(!!request);
        Io.DaemonSessions.sessions["bar-daemon"].client.response(request.id,
            {protocol: Contract.protocol, version: Contract.version, ok: true, data: data}, "", request.route);
    }
    function capture(root, name): void {
        wait(80);
        verify(waitForPolish(root.Window.window));
        const directory = decodeURIComponent(Qt.resolvedUrl("../../target/update-panel-implementation/captures/").toString().replace(/^file:\/\//, ""));
        let saved = false;
        verify(root.grabToImage(image => { saved = image.saveToFile(directory + name + ".png"); }));
        tryVerify(() => saved);
    }
    function test_pages_data(): var {
        return [{tag: "dark", theme: Qt.Dark, width: 1040, height: 720},
            {tag: "light", theme: Qt.Light, width: 1040, height: 720},
            {tag: "dark-minimum", theme: Qt.Dark, width: 976, height: 600},
            {tag: "light-minimum", theme: Qt.Light, width: 976, height: 600}];
    }
    function test_pages(data): void {
        Ui.Theme.previewColorScheme = data.theme;
        const root = createTemporaryObject(factory, testCase, {width: data.width, height: data.height});
        root.controller.activateUi("");
        tryVerify(() => calls.some(call => call.method === "updates.getOverview"));
        const run = {schema_version: 1, lane: "ai-tools", title: "Partial · AI tools", outcome: "partial",
            job: {id: "example-run", operation: "ai-update", phase: "verifying", status: "failed", started_at: 1792575700, finished_at: 1792575800, exit_code: 1, error: "Verification failed: expected executable not found"},
            components: [{name: "Tool A", before: "1.2.0", after: "1.3.0", changed: true, phase: "activated", error: null},
                {name: "Tool B", before: "2.0.0", after: "2.0.0", changed: false, phase: "failed", error: "Verification failed"}]};
        respond("updates.queryHistory", {history: {available: true, revision: "review", entries: [run], cursor: null, total: 1, coverage: "Worker-managed system and tool runs", error: null}});
        respond("updates.getOverview", {overview: {
            schema_version: 1, available: true, observed_at: 1792575900, error: null, history_available: true, history_error: null, issue_total: 1,
            issues: [{run_id: "example-run", lane: "ai-tools", component: "Tool B", incident: null, error: "Verification failed", failed_at: 1792575800}],
            system: {active: "/nix/store/aaaaaaaaaaaaaaaa-nixos-system-host-26.05.312", booted: "/nix/store/aaaaaaaaaaaaaaaa-nixos-system-host-26.05.312", profile: "/nix/store/bbbbbbbbbbbbbbbb-nixos-system-host-26.05.328", staged_for_next_boot: true, staged_since: 1792575000, pending_transaction: false, queued: false, last_successful_check: 1792574000, errors: []},
            baseline: {valid: true, approved_at: 1792575000, revision: "9ba7c24", reasons: [], error: null},
            tools: ["Tool A", "Tool B", "Tool C", "Tool D", "Tool E"].map((name, index) => ({name: name, installed_version: "1.2.3", phase: index === 1 ? "failed" : "current", last_successful_check: 1792575300, last_activation: 1792500000, error: index === 1 ? "Verification failed" : null,
                freshness: {latest_version: index < 2 ? "1.3.0" : "1.2.3", comparison: index < 2 ? "newer" : "current", source: "https://vendor.example/releases/stable", stale: false, held: false, hold_since: null, hold_reason: null, origin: "vendor", published_at: null}})),
            applications: {available: true, active_system: "/nix/store/aaaaaaaaaaaaaaaa-nixos-system-host-26.05.312", observed_at: 1792575900, total: 12, error: null,
                packages: ["browser", "editor", "image-editor", "media-player", "terminal", "versionless-wrapper"].map((name, index) => ({name: name, scope: index < 4 ? "system" : "user:example", version: index === 5 ? null : "1.2.3",
                    release: index > 3 ? null : {version: index === 3 ? null : "1.3.0", source: "https://api.github.com/repos/example/" + name + "/releases/latest",
                        checked_at: index === 3 ? null : 1792575000, attempted_at: index === 3 ? null : 1792575900,
                        stale: index > 0, error: index === 2 ? "HTTP 429: rate limited" : null}}))},
            timers: [{unit: "nixos-update-delayed.timer", next_at: 1792580000, last_at: 1792574000}], timers_error: null,
            git: {available: true, path: "/home/example/Projects/nixos-config", branch: "main", revision: "6c31a9e".repeat(5), upstream: "origin/main", ahead: 0, behind: 4, dirty: true, shallow: false, observed_at: 1792575900, target_observed_at: null, error: null}
        }});
        root.controller.nowMs = 1792575900000;
        root.controller.openDetails();
        for (const page of ["overview", "git", "ai", "applications", "system"]) {
            root.controller.selectDetailsTab(page);
            capture(root, data.tag + "-" + page);
            if (page === "applications") {
                const inventory = findChild(root, "updateApplicationsOverview");
                const height = inventory.height;
                mouseClick(findChild(inventory, "sectionHeadingHelp"));
                compare(inventory.height, height);
                capture(root, data.tag + "-applications-help");
                mouseClick(findChild(findChild(inventory, "updateApplication:system:browser"), "updateApplicationStatus"));
                compare(inventory.height, height);
                capture(root, data.tag + "-applications-status");
            }
        }
        root.controller.openSettings("");
        capture(root, data.tag + "-settings");
        root.controller.selectedIndex = 1;
        root.controller.openDetails();
        tryVerify(() => calls.some(call => call.method === "updates.readLog"));
        respond("updates.readLog", {log: {run_id: "example-run", text: "Checking vendor releases\nTool A activated\nerror: Tool B verification failed\nwarning: one update remains unresolved", truncated: false}});
        for (const page of ["summary", "changes", "log"]) {
            root.controller.selectDetailsTab(page);
            capture(root, data.tag + "-" + page);
        }
    }
}
