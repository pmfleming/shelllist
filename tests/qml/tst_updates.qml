pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import "../../bar/BarProtocol.generated.js" as Contract
import "../../bar/UpdatePresentation.js" as Presentation
import "../../qml/Shelllist/Ui/MaterialIcons.js" as Icons

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
    function reply(call, entries, cursor, published, error, total): void {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, {protocol: Contract.protocol, version: Contract.version, ok: true, data: {history: {
            available: published !== false, revision: "revision", entries: entries, cursor: cursor || null, total: total === undefined ? entries.length : total, coverage: "Worker-managed runs", error: error || null
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
        compare(root.controller.backend.expectedVersion, Contract.version);
        compare(root.controller.backend.expectedProtocol, Contract.protocol);
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
    function test_manualRebuildUsesTheSameReadOnlyHistoryAndLogRoute(): void {
        const root = fixture();
        const run = entry("manual-123-rebuild-test", "activated");
        run.title = "System rebuilt successfully";
        run.job.operation = "manual-rebuild";
        run.components = [{name: "NixOS system", before: "/nix/store/old-system", after: "/nix/store/new-system", changed: true, phase: "activated", error: null}];
        reply(latest(), [run]);
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.controller.detailsOpen && root.content.detailsNavigation.contentReady);
        keyClick(Qt.Key_V, Qt.AltModifier);
        const request = calls.filter(call => call.method === "updates.readLog").slice(-1)[0];
        verify(request !== undefined);
        compare(request.params.run_id, run.job.id);
        Io.DaemonSessions.sessions["bar-daemon"].client.response(request.id, {
            protocol: Contract.protocol, version: Contract.version, ok: true,
            data: {log: {run_id: run.job.id, text: "Rebuild completed", truncated: false}}
        }, "", request.route);
        compare(root.controller.selectedLog, "Rebuild completed");
        compare(root.controller.errorText, "");
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
        verify(root.controller.warningText.includes("no longer retained"));
        compare(root.controller.errorText, "");
        verify(!root.controller.detailsOpen);
    }
    function test_readableRowsAndDetailsKeepDateHeadersOutOfNavigation(): void {
        const root = fixture();
        const now = new Date(2026, 9, 21, 12).getTime();
        root.controller.nowMs = now;
        const run = entry("changed", "partial");
        run.lane = "ai-tools";
        run.job.operation = "ai-update";
        run.job.status = "failed";
        run.job.started_at = now / 1000 - 120;
        run.job.finished_at = now / 1000 - 20;
        run.job.exit_code = 1;
        run.components = [
            {name: "A", before: "1", after: "2", changed: true, phase: "activated", error: null},
            {name: "B", before: "1", after: "2", changed: true, phase: "activated", error: null},
            {name: "C", before: "1", after: "1", changed: false, phase: "failed", error: "Build failed"}
        ];
        reply(latest(), [run, entry("older", "staged")], null, true, null, 312);
        compare(root.controller.countLabel, "2 of 312 runs · read only");
        tryCompare(root.content.listItem, "resultCount", 2);
        const row = findChild(root, "updateRun:changed");
        verify(row !== null);
        verify(row.accessibleName.includes("2 tools changed / 1 failed"));
        verify(row.accessibleName.includes("AI tools · Partial"));
        compare(findChild(root, "updateDate:changed").title, "Today");
        compare(findChild(root, "updateDate:older").title, "Older");
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        const card = findChild(root, "updateRecordedOutcome");
        compare(card.entries[0].value, "Failed · Partial");
        compare(card.entries.find(field => field.label === "Duration").value, "1 min 40 s");
        compare(card.entries.find(field => field.label === "Exit code").value, "1 (failed)");
        keyClick(Qt.Key_Down);
        compare(root.controller.selectedRun.job.id, "older");
        verify(root.controller.detailsOpen);
        verify(root.content.listItem.listFocused);
    }
    function test_liveDurationTicksWithoutReadsOrFocusChanges(): void {
        const root = fixture();
        const run = entry("running", "running");
        run.job.status = "running";
        run.job.started_at = Math.floor(Date.now() / 1000) - 60;
        run.job.finished_at = null;
        reply(latest(), [run]);
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        const card = findChild(root, "updateRecordedOutcome");
        const duration = () => card.entries.find(field => field.label === "Duration").value;
        const before = duration();
        const requests = calls.length;
        verify(before.includes("elapsed"));
        verify(!card.entries.some(field => field.label === "Finished"));
        tryVerify(() => duration() !== before, 2500);
        compare(calls.length, requests);
        compare(root.controller.selectedRun.job.id, "running");
        verify(root.content.listItem.listFocused);
        root.controller.deactivateUi();
        const stopped = root.controller.nowMs;
        wait(1100);
        compare(root.controller.nowMs, stopped);
    }
    function test_partialHistoryPublishesGoodRowsAndDoesNotBecomeAnOutage(): void {
        const root = fixture();
        reply(latest(), [entry("cached", "staged")]);
        root.controller.refresh();
        reply(latest(), [entry("readable", "activated")], "revision:1", true, "broken.json: Invalid record\nMore diagnostic text", 3);
        compare(root.controller.entries[0].job.id, "readable");
        compare(root.controller.errorText, "");
        verify(root.controller.warningBrief.includes("Some update history"));
        compare(root.controller.cursor, "revision:1");
        root.controller.loadMore();
        reply(latest(), [entry("second", "current"), entry("third", "failed")], null, true, "broken.json: Invalid record", 3);
        compare(root.controller.entries.length, 3);
        compare(root.controller.total, 3);
        root.controller.refresh();
        reply(latest(), [], null, true, "broken.json: Invalid record");
        compare(root.controller.entries.length, 0);
        compare(root.controller.errorText, "");
        compare(root.content.listItem.emptyState, "empty");
        root.controller.refresh();
        reply(latest(), [], null, false, "Cannot open history");
        compare(root.content.listItem.emptyState, "unavailable");
        verify(root.controller.errorText.includes("Cannot open history"));
    }
    function test_logLoadingAndFailuresStayWithTheirRun(): void {
        const root = fixture();
        reply(latest(), [entry("one", "failed"), entry("two", "staged")]);
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        root.controller.errorText = "History read failed";
        keyClick(Qt.Key_V, Qt.AltModifier);
        const request = calls.filter(call => call.method === "updates.readLog").slice(-1)[0];
        verify(root.controller.selectedLogLoading);
        compare(findChild(root, "updateRunLogText").text, "Reading log…");
        keyClick(Qt.Key_Down);
        verify(!root.controller.selectedLogLoading);
        Io.DaemonSessions.sessions["bar-daemon"].client.response(request.id, null, "Journal access denied", request.route);
        compare(root.controller.errorText, "History read failed");
        compare(root.controller.selectedLogError, "");
        keyClick(Qt.Key_Up);
        compare(root.controller.selectedLogError, "Journal access denied");
        compare(findChild(root, "updateRunLogText").text, "Journal access denied");
        keyClick(Qt.Key_V, Qt.AltModifier);
        verify(root.controller.selectedLogLoading);
        compare(root.controller.selectedLogError, "");
        const retry = calls.filter(call => call.method === "updates.readLog").slice(-1)[0];
        Io.DaemonSessions.sessions["bar-daemon"].client.response(retry.id, {
            protocol: Contract.protocol, version: Contract.version, ok: true,
            data: {log: {run_id: "another-run", text: "Not ours", truncated: false}}
        }, "", retry.route);
        compare(root.controller.selectedLogError, "Invalid update log reply");
        compare(root.controller.errorText, "History read failed");
        verify(!root.controller.selectedLogLoading);
    }
    function test_presentationPreservesOutcomeAndTimeSemantics(): void {
        const outcomes = ["activated", "staged", "ready", "running", "queued", "current", "blocked", "failed", "partial", "interrupted", "available", "skipped", "approved", "completed"];
        const icons = outcomes.map(Presentation.outcomeIcon);
        compare(new Set(icons).size, outcomes.length);
        verify(icons.every(icon => Icons.name(icon) !== ""));
        compare(Presentation.outcomeIcon("new-outcome"), "history");
        compare(Presentation.label("ai-tools-stale"), "AI tools stale check");
        compare(Presentation.label("manual-rebuild"), "Manual system rebuild");
        compare(Presentation.label("run-delayed"), "Run deferred system update");
        compare(Presentation.label("never-checked"), "Never checked");
        compare(Presentation.label("future-phase"), "Future phase");
        compare(Presentation.exitLabel(130), "130 (cancelled)");
        compare(Presentation.exitLabel(0), "0 (success)");
        compare(Presentation.exitLabel(42), "42");
        compare(Presentation.exitLabel(null), "Not recorded");
        const now = new Date(2026, 9, 21, 12).getTime();
        compare(Presentation.timeLabel(new Date(2026, 9, 21, 9, 42).getTime() / 1000, now), "Today 09:42");
        compare(Presentation.timeLabel(new Date(2026, 9, 20, 9, 42).getTime() / 1000, now), "Yesterday 09:42");
        compare(Presentation.timeLabel(null, now), "Not recorded");
        compare(Presentation.dateGroup(new Date(2026, 9, 19).getTime() / 1000, now), "This week");
        compare(Presentation.dateGroup(new Date(2026, 9, 18).getTime() / 1000, now), "This month");
        compare(Presentation.dateGroup(new Date(2026, 8, 30).getTime() / 1000, now), "Older");
        const interrupted = entry("abandoned", "interrupted");
        interrupted.job.status = "running";
        interrupted.job.finished_at = null;
        compare(Presentation.durationLabel(interrupted, now), "Unknown duration");
        interrupted.job.finished_at = 50;
        compare(Presentation.durationLabel(interrupted, now), "Unknown duration");
        const current = entry("current", "current");
        current.components = [{changed: false, phase: "activated", error: null}];
        compare(Presentation.changeSummary(current), "No component changes");
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
