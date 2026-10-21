pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io

DaemonTestCase {
    id: testCase
    name: "Updates"
    when: windowShown
    visible: true
    width: 1100
    height: 720
    Component {
        id: factory
        Item {
            anchors.fill: parent
            property alias controller: controller
            property alias content: content
            Bar.UpdateController { id: controller }
            Bar.UpdateContent { id: content; anchors.fill: parent; controller: controller }
        }
    }
    function init(): void { calls = []; failOnWarning(/.*/); }
    function entry(id, outcome): var {
        return {schema_version: 1, lane: "system", title: outcome === "staged" ? "Staged for next boot" : "Update failed", outcome: outcome,
            job: {id: id, operation: "run-delayed", phase: outcome, status: "completed", started_at: 100, finished_at: 200, exit_code: 0, error: null}, components: []};
    }
    function reply(call, entries, cursor, published): void {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, {protocol: "bar-api", version: 1, ok: true, data: {history: {
            available: published !== false, revision: "revision", entries: entries, cursor: cursor || null, total: entries.length, coverage: "Worker-managed runs", error: null
        }}}, "", call.route);
    }
    function latest(): var { return calls.filter(call => call.method === "updates.queryHistory").slice(-1)[0]; }
    function fixture(): var {
        const root = createTemporaryObject(factory, testCase);
        verify(root !== null);
        root.controller.activateUi("");
        tryVerify(() => latest() !== undefined);
        return root;
    }
    function test_browseInspectAndLogCommandNeverRunAnUpdate(): void {
        const root = fixture();
        reply(latest(), [entry("run-1", "staged"), entry("run-2", "failed")]);
        tryCompare(root.controller, "hasSelection", true);
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.controller.detailsOpen && root.content.detailsNavigation.contentReady);
        keyClick(Qt.Key_Down);
        compare(root.controller.selectedRun.job.id, "run-2");
        keyClick(Qt.Key_V, Qt.AltModifier);
        tryVerify(() => calls.some(call => call.method === "updates.readLog"));
        const log = calls.filter(call => call.method === "updates.readLog").slice(-1)[0];
        compare(log.params.run_id, "run-2");
        verify(calls.every(call => ["updates.queryHistory", "updates.readLog", "bar.snapshot"].includes(call.method)));
    }
    function test_staleRepliesMalformedPagesAndRefreshRetainThePublishedRows(): void {
        const root = fixture();
        reply(latest(), [entry("run-1", "staged")]);
        compare(root.controller.entries.length, 1);
        root.controller.refresh();
        const old = latest();
        root.controller.filterText = "failed";
        root.controller.refresh();
        const current = latest();
        reply(old, [entry("obsolete", "failed")]);
        compare(root.controller.entries[0].job.id, "run-1");
        reply(current, [entry("duplicate", "failed"), entry("duplicate", "failed")]);
        verify(root.controller.errorText.includes("Duplicate"));
        compare(root.controller.entries[0].job.id, "run-1");
        root.controller.refresh();
        reply(latest(), [entry("run-2", "failed")]);
        compare(root.controller.entries[0].job.id, "run-2");
        compare(root.controller.errorText, "");
        root.controller.refresh();
        reply(latest(), [], null, false);
        compare(root.controller.entries[0].job.id, "run-2");
        verify(root.controller.errorText.includes("cached"));
    }
    function test_prunedDeepLinkReturnsToHistoryWithoutOpeningAnotherRun(): void {
        const root = fixture();
        root.controller.openRun("pruned-run");
        reply(latest(), []);
        compare(latest().params.run_id, null);
        reply(latest(), [entry("recent-run", "staged")]);
        compare(root.controller.entries[0].job.id, "recent-run");
        verify(root.controller.errorText.includes("no longer retained"));
        verify(!root.controller.detailsOpen);
    }
    function test_exactRunAndCloseFenceTheRead(): void {
        const root = fixture();
        root.controller.openRun("run-42");
        const request = latest();
        compare(request.params.run_id, "run-42");
        reply(request, [entry("run-42", "staged")]);
        compare(root.controller.selectedRun.job.id, "run-42");
        verify(root.controller.detailsOpen);
        root.controller.refresh();
        const late = latest();
        root.controller.deactivateUi();
        reply(late, [entry("late", "failed")]);
        compare(root.controller.entries[0].job.id, "run-42");
    }
}
