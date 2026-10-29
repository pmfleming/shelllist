pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import "../qml" as Tests

// Non-gating wall-clock diagnostic. The regular Updates suite gates delegate
// bounds and native navigation; this fixture records timings without live I/O.
Tests.DaemonTestCase {
    id: testCase
    name: "UpdatePerformance"
    when: windowShown
    visible: true
    width: 1040
    height: 720
    Component {
        id: factory
        Item {
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            property alias content: content
            Bar.UpdateController { id: controller }
            Bar.UpdateContent { id: content; anchors.fill: parent; controller: controller }
        }
    }
    function init(): void { calls = []; failOnWarning(/.*/); }
    function itemCount(item): int {
        let count = 1;
        for (const child of item.children || []) count += itemCount(child);
        return count;
    }
    function snapshot(count): var {
        return {schema_version: 1, available: true, observed_at: 400, error: null,
            history_available: true, history_error: null, issue_total: 0, issues: [],
            system: null, baseline: null, tools: [], timers: [], timers_error: null, git: null,
            applications: {available: true, active_system: "/nix/store/example", observed_at: 400,
                total: count, error: null, packages: Array.from({length: count}, (_, i) => ({
                    name: "package-" + i, scope: "system", version: "1.2.3", release: null}))}};
    }
    function test_population_data(): var {
        return [{tag: "empty", count: 0}, {tag: "193-packages", count: 193}, {tag: "512-packages", count: 512}];
    }
    function test_population(data): void {
        const root = createTemporaryObject(factory, testCase);
        root.controller.activateUi("");
        root.controller.selectFirst();
        root.controller.openDetails();
        tryVerify(() => root.content.detailsNavigation.contentReady);
        let start = Date.now();
        root.controller.overview = snapshot(data.count);
        console.log("Overview publication:", data.count, "packages,", Date.now() - start, "ms,", itemCount(root), "items");
        compare(findChild(root, "updateApplicationsOverview"), null);
        start = Date.now();
        root.controller.selectDetailsTab("applications");
        tryVerify(() => root.content.detailsNavigation.contentReady);
        verify(waitForPolish(root.Window.window));
        console.log("Applications ready:", data.count, "packages,", Date.now() - start, "ms,", itemCount(root), "items");
        compare(findChild(root, "updateApplicationsList").count, data.count);
        root.controller.deactivateUi();
        verify(calls.every(call => ["updates.queryHistory", "updates.getOverview"].includes(call.method)));
    }
}
