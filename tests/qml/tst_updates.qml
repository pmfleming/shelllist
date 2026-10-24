pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "../../clipboard/ClipApi.js" as ClipApi
import "../../bar/BarProtocol.generated.js" as Contract
import "../../bar/UpdatePresentation.js" as Presentation
import "../../bar/UpdateHistory.js" as History

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
            property alias barState: barState
            Bar.BarController { id: barState; surfaceRegistry: null }
            Bar.UpdateController { id: controller; barController: barState }
            Bar.UpdateContent { id: content; anchors.fill: parent; controller: controller }
        }
    }
    function init(): void { calls = []; failOnWarning(/.*/); }
    function entry(id, outcome): var {
        return {schema_version: 1, lane: "system", title: outcome === "staged" ? "Staged for next boot" : "Update failed", outcome: outcome,
            job: {id: id, operation: "run-delayed", phase: outcome, status: "completed", started_at: 100, finished_at: 200, exit_code: 0, error: null}, components: []};
    }
    function reply(call, entries, cursor, published, error, total, extra): void {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, {protocol: Contract.protocol, version: Contract.version, ok: true, data: {history: Object.assign({
            available: published !== false, revision: "revision", entries: entries, cursor: cursor || null, total: total === undefined ? entries.length : total, coverage: "Worker-managed runs", error: error || null
        }, extra || {})}}, "", call.route);
    }
    function historyFailure(call, code): void {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, {protocol: Contract.protocol, version: Contract.version, ok: false,
            error: {code: code, message: "History changed"}}, "", call.route);
    }
    function historyRuns(count): var {
        return Array.from({length: count}, (_, index) => entry("history-" + index, "staged"));
    }
    function latest(): var { return calls.filter(call => call.method === "updates.queryHistory").slice(-1)[0]; }
    function fixture(): var {
        const root = createTemporaryObject(factory, testCase);
        verify(root !== null);
        root.controller.activateUi("");
        tryVerify(() => latest() !== undefined);
        return root;
    }
    function focusFirstRun(root): void {
        root.controller.selectedIndex = 1;
        root.content.listItem.focusList();
    }
    function showPage(root, page): void {
        root.content.listItem.focusList();
        for (let i = 0; root.controller.detailsTab !== page && i < 6; ++i) {
            keyClick(Qt.Key_Tab, Qt.ControlModifier);
            wait(0);
        }
        compare(root.controller.detailsTab, page);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        wait(20);
    }
    function test_filtersUseSharedFieldsBehindSearchGearAndDateSearchUsesNativeKeys(): void {
        verify(["layers", "filter_alt", "unfold_less", "unfold_more"].every(icon => Ui.MaterialIcons.name(icon) === icon));
        const root = fixture();
        reply(latest(), historyRuns(50));
        root.content.listItem.focusList();
        const before = calls.length;
        keyClick(Qt.Key_F, Qt.AltModifier);
        tryCompare(root.controller, "settingsOpen", true);
        tryVerify(() => root.content.detailsNavigation.browsing && root.content.detailsNavigation.contentReady
            && !root.content.detailsNavigation.pendingMemory && root.content.detailsNavigation.highlightedControl === findChild(root, "updateOutcomeFilter"));
        compare(findChild(root, "updateFilterMenu"), null);
        compare(root.content.listItem.listOptionsComponent, null);
        compare(calls.length, before);
        keyClick(Qt.Key_Return);
        tryVerify(() => root.content.detailsNavigation.editing);
        keyClick(Qt.Key_Down);
        compare(root.controller.outcomeFilter, "");
        compare(calls.length, before);
        keyClick(Qt.Key_Escape);
        compare(root.controller.outcomeFilter, "");
        keyClick(Qt.Key_Return);
        tryVerify(() => root.content.detailsNavigation.editing);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        tryCompare(root.controller, "outcomeFilter", "problems");
        compare(latest().params.outcome, "problems");
        reply(latest(), [entry("problem", "failed")]);
        keyClick(Qt.Key_T, Qt.AltModifier);
        tryVerify(() => root.content.detailsNavigation.browsing && !root.content.detailsNavigation.pendingMemory
            && root.content.detailsNavigation.highlightedControl === findChild(root, "updateLaneFilter"));
        keyClick(Qt.Key_Return);
        tryVerify(() => root.content.detailsNavigation.editing);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Tab);
        tryCompare(root.controller, "laneFilter", "system");
        // Tab saves one field and edits the next; Escape must not save it.
        keyClick(Qt.Key_Escape);
        compare(latest().params.lane, "system");
        const superseded = latest();
        root.content.listItem.focusSearch();
        for (const key of [Qt.Key_T, Qt.Key_O, Qt.Key_D, Qt.Key_A, Qt.Key_Y]) keyClick(key);
        tryVerify(() => latest().params.query === "today");
        reply(superseded, [entry("stale-filter", "failed")]);
        compare(root.controller.entries[0].job.id, "problem");
        reply(latest(), []);
        compare(root.controller.filteredResults[0].id, "_now");
        compare(root.content.listItem.emptyState, "filtered");
        const beforeMidnight = latest().id;
        root.controller.nowMs = new Date(2026, 9, 20, 23, 59).getTime();
        root.controller.nowMs = new Date(2026, 9, 21, 0, 1).getTime();
        tryVerify(() => latest().id !== beforeMidnight);
        compare(latest().params.query, "today");
        reply(latest(), []);
        root.controller.openRun("exact");
        compare(latest().params.lane, null);
        compare(latest().params.outcome, null);
        compare(latest().params.query, "");
        reply(latest(), [entry("exact", "current")]);
        compare(root.controller.selectedRun.job.id, "exact");
        verify(calls.every(call => ["updates.queryHistory", "updates.getOverview", "updates.readLog", "bar.snapshot"].includes(call.method)));
    }
    function test_noChangeGroupsExpandWithoutHidingFailuresOrInventingRuns(): void {
        const root = fixture();
        const runs = Array.from({length: 8}, (_, index) => entry("quiet-" + index, "current"));
        runs[3].outcome = "failed";
        runs[6].job.operation = "manual-rebuild";
        runs[7].components = [{name: "pi", phase: "held", changed: false, before: null, after: null, error: null}];
        verify(!History.routine(runs[3]) && !History.routine(runs[6]) && !History.routine(runs[7]));
        const changed = entry("changed-current", "current");
        changed.components = [{name: "pi", phase: "activated", changed: true, error: null, incident: null}];
        verify(!History.routine(changed));
        changed.components[0].changed = false;
        changed.components[0].incident = "pi:failure";
        verify(!History.routine(changed));
        reply(latest(), runs);
        compare(root.controller.entries.length, 8);
        compare(root.controller.foldedCount, 5);
        compare(root.controller.filteredResults.length, 6);
        focusFirstRun(root);
        const requests = calls.length;
        keyClick(Qt.Key_Return);
        compare(root.controller.selectedQuietGroup.expanded, true);
        compare(root.controller.foldedCount, 2);
        compare(calls.length, requests);
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        verify(findChild(root, "updateQuietGroup").visible);
        keyClick(Qt.Key_Down);
        compare(root.controller.selectedRun.job.id, "quiet-0");
        keyClick(Qt.Key_V, Qt.AltModifier);
        compare(logCalls().slice(-1)[0].params.run_id, "quiet-0");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_E, Qt.AltModifier);
        compare(root.controller.foldedCount, 5);
        const groupId = root.controller.selectedResult.id;
        root.controller.refresh();
        reply(latest(), [entry("new-quiet", "current")].concat(runs));
        compare(root.controller.selectedResult.id, groupId);
        keyClick(Qt.Key_Return);
        compare(root.controller.selectedResult.id, groupId);
        verify(root.controller.selectedQuietGroup.expanded);
        keyClick(Qt.Key_N, Qt.AltModifier);
        compare(root.controller.collapseRoutine, false);
        compare(root.controller.foldedCount, 0);
        compare(root.controller.filteredResults.length, 10);
    }
    function test_routineGroupingRespectsBoundariesAndRememberedAnchorOrder(): void {
        const runs = ["a", "b", "c", "d", "e", "f"].map(id => entry(id, "current"));
        runs.forEach((run, index) => run.job.started_at = new Date(2026, 9, index < 2 ? 20 : 21, 12).getTime() / 1000);
        runs[4].lane = runs[5].lane = "ai-tools";
        const rows = History.project(runs, true, ["b", "a"], "d");
        const groups = rows.filter(row => row.quietGroup).map(row => row.quietGroup);
        compare(groups.map(group => group.id), ["_quiet-b", "_quiet-c", "_quiet-e"]);
        compare(groups.map(group => group.expanded), [true, true, false]);
        compare(rows.filter(row => row.run).map(row => row.run.job.id), ["a", "b", "c", "d"]);
        compare(History.project(runs, true, ["b"], "_quiet-a")[0].quietGroup.id, "_quiet-a");
        compare(History.project(runs, false, ["b"], "d").map(row => row.run.job.id), runs.map(run => run.job.id));
    }
    function test_refreshStagesLoadedDepthAndPreservesSelectionViewportAndFocus(): void {
        const root = fixture();
        const old = historyRuns(120);
        reply(latest(), old.slice(0, 50), "v1:50", true, null, 120, {revision: "v1"});
        root.controller.loadMore();
        reply(latest(), old.slice(50, 100), "v1:100", true, null, 120, {revision: "v1"});
        root.controller.selectedIndex = 76;
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        const list = findChild(root, "resultListView");
        wait(20);
        list.positionViewAtIndex(65, ListView.Beginning);
        const viewport = root.content.listItem.sessionState().viewport;
        verify(viewport !== null);
        const fresh = [entry("new-0", "staged"), entry("new-1", "staged"), entry("new-2", "staged")].concat(old);
        keyClick(Qt.Key_F5);
        compare(latest().params.anchor_ids.join(","), "history-75,history-99");
        reply(latest(), fresh.slice(0, 50), "v2:50", true, null, 123, {revision: "v2", retain_through: 103});
        compare(root.controller.entries.length, 100);
        compare(root.controller.selectedRun.job.id, "history-75");
        compare(latest().params.cursor, "v2:50");
        reply(latest(), fresh.slice(50, 100), "v2:100", true, null, 123, {revision: "v2", retain_through: 103});
        compare(root.controller.entries[0].job.id, "history-0");
        reply(latest(), fresh.slice(100), null, true, null, 123, {revision: "v2", retain_through: 103});
        tryCompare(root.controller, "selectedIndex", 79);
        tryCompare(root.content.listItem, "resultCount", 124);
        tryVerify(() => root.content.listItem.sessionState().viewport.key === viewport.key);
        verify(Math.abs(root.content.listItem.sessionState().viewport.offset - viewport.offset) < 2);
        compare(root.controller.selectedRun.job.id, "history-75");
        verify(root.content.listItem.listFocused && root.controller.detailsOpen);
        compare(root.controller.loading, false);
    }
    function test_staleCursorRetriesOnceAndFailedContinuationsNeverPublish(): void {
        const root = fixture();
        const runs = historyRuns(120);
        reply(latest(), runs.slice(0, 50), "v1:50", true, null, 120, {revision: "v1"});
        root.controller.loadMore();
        historyFailure(latest(), "update-history-cursor-stale");
        compare(latest().params.cursor, null);
        reply(latest(), runs.slice(0, 50), "v2:50", true, null, 120, {revision: "v2", retain_through: 50});
        compare(root.controller.entries.length, 50);
        compare(latest().params.cursor, "v2:50");
        const last = latest();
        historyFailure(last, "update-history-cursor-stale");
        compare(latest().id, last.id);
        compare(root.controller.loading, false);
        compare(root.controller.entries.length, 50);
        verify(root.controller.errorText.length > 0);
        root.controller.refresh();
        const first = latest();
        reply(first, runs.slice(0, 25), "v3:25", true, null, 120, {revision: "v3", retain_through: 50});
        compare(root.controller.entries.length, 50);
        reply(latest(), runs.slice(20, 50), "v3:55", true, null, 120, {revision: "v3", retain_through: 50});
        verify(root.controller.errorText.includes("Duplicate"));
        compare(root.controller.publishedRevision, "v1");
        compare(root.controller.entries.length, 50);
        root.controller.refresh();
        reply(latest(), [], null, true, null, 120, {revision: "bad-end"});
        verify(root.controller.errorText.includes("continuation"));
        compare(root.controller.entries.length, 50);
        root.controller.refresh();
        reply(latest(), runs.slice(0, 25), "v4:25", true, null, 120, {revision: "v4", retain_through: 50});
        const late = latest();
        root.controller.deactivateUi();
        reply(late, runs.slice(25, 50), "v4:50", true, null, 120, {revision: "v4", retain_through: 50});
        compare(root.controller.publishedRevision, "v1");
        compare(root.controller.historyWindow, null);
    }
    function test_continuationRejectsChangedMetadata_data(): var {
        return [
            {tag: "total", total: 121, cursor: "next", retain: 50},
            {tag: "retention", total: 120, cursor: "next", retain: 51},
            {tag: "cursor", total: 120, cursor: "refresh:25", retain: 50}
        ];
    }
    function test_continuationRejectsChangedMetadata(data): void {
        const root = fixture();
        const runs = historyRuns(120);
        reply(latest(), runs.slice(0, 50), "old:50", true, null, 120);
        root.content.listItem.focusList();
        keyClick(Qt.Key_F5);
        reply(latest(), runs.slice(0, 25), "refresh:25", true, null, 120, {revision: "refresh", retain_through: 50});
        const staged = root.controller.historyWindow;
        reply(latest(), runs.slice(25, 50), data.cursor, true, null, data.total, {revision: "refresh", retain_through: data.retain});
        verify(root.controller.errorText.includes("continuation"));
        compare(root.controller.entries.length, 50);
        compare(root.controller.publishedRevision, "revision");
        compare(root.controller.historyWindow, null);
        compare(staged.entries.length, 25, "Rejected pages cannot mutate the unpublished window");
        compare(staged.pages, 1);
    }
    function test_browseInspectAndLogCommandNeverRunAnUpdate(): void {
        const root = fixture();
        compare(root.controller.backend.expectedVersion, Contract.version);
        compare(root.controller.backend.expectedProtocol, Contract.protocol);
        reply(latest(), [entry("run-1", "staged"), entry("run-2", "failed")]);
        tryCompare(root.controller, "hasSelection", true);
        focusFirstRun(root);
        keyClick(Qt.Key_Right);
        tryVerify(() => root.controller.detailsOpen && root.content.detailsNavigation.contentReady);
        keyClick(Qt.Key_Down);
        compare(root.controller.selectedRun.job.id, "run-2");
        keyClick(Qt.Key_V, Qt.AltModifier);
        tryVerify(() => calls.some(call => call.method === "updates.readLog"));
        const log = calls.filter(call => call.method === "updates.readLog").slice(-1)[0];
        compare(log.params.run_id, "run-2");
        verify(calls.every(call => ["updates.queryHistory", "updates.getOverview", "updates.readLog", "bar.snapshot"].includes(call.method)));
    }
    function test_manualRebuildUsesTheSameReadOnlyHistoryAndLogRoute(): void {
        const root = fixture();
        const run = entry("manual-123-rebuild-test", "activated");
        run.title = "System rebuilt successfully";
        run.job.operation = "manual-rebuild";
        run.components = [{name: "NixOS system", before: "/nix/store/old-system", after: "/nix/store/new-system", changed: true, phase: "activated", error: null}];
        reply(latest(), [run]);
        focusFirstRun(root);
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
    function test_exactRunRejectsUnrelatedAndUnreadableReplies_data(): var {
        return [
            {tag: "other-target", ids: ["other"], error: null},
            {tag: "mixed-targets", ids: ["wanted", "other"], error: null},
            {tag: "unreadable-not-pruned", ids: [], error: "Run could not be read"}
        ];
    }
    function test_exactRunRejectsUnrelatedAndUnreadableReplies(data): void {
        const root = fixture();
        reply(latest(), [entry("cached", "staged")]);
        root.controller.openRun("wanted");
        const owned = latest();
        reply(owned, data.ids.map(id => entry(id, "staged")), null, true, data.error);
        compare(root.controller.runId, "wanted");
        compare(root.controller.entries.map(run => run.job.id), ["cached"]);
        compare(root.controller.historyWindow, null);
        verify(!root.controller.loading && !root.controller.detailsOpen && !root.controller.missingRun);
        compare(latest().id, owned.id, "invalid/unreadable exact links do not query unrelated history");
        verify(!!(root.controller.errorText || root.controller.warningText));
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
        reply(latest(), [run, entry("older", "staged")], "revision:2", true, null, 312);
        compare(root.controller.countLabel, "2 of 312 runs · read only");
        tryCompare(root.content.listItem, "resultCount", 3);
        const row = findChild(root, "updateRun:changed");
        verify(row !== null);
        verify(row.accessibleName.includes("2 tools changed / 1 failed"));
        verify(row.accessibleName.includes("AI tools · Partial"));
        compare(findChild(root, "updateDate:changed").title, "Today");
        compare(findChild(root, "updateDate:older").title, "Older");
        focusFirstRun(root);
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        const card = findChild(root, "updateRecordedOutcome");
        compare(card.rows.find(field => field.label === "Outcome").value, "Partial");
        compare(card.rows.find(field => field.label === "Job status").value, "Failed");
        compare(card.rows.find(field => field.label === "Duration").value, "1 min 40 s");
        compare(card.rows.find(field => field.label === "Exit code").value, "1 (failed)");
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
        focusFirstRun(root);
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        const card = findChild(root, "updateRecordedOutcome");
        const duration = () => card.rows.find(field => field.label === "Duration").value;
        const before = duration();
        const requests = calls.length;
        verify(before.includes("elapsed"));
        verify(!card.rows.some(field => field.label === "Finished"));
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
        focusFirstRun(root);
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
        verify(icons.every(icon => Ui.MaterialIcons.name(icon) !== ""));
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
    function logReply(request, text, truncated, error): void {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(request.id, error ? null : {
            protocol: Contract.protocol, version: Contract.version, ok: true,
            data: {log: {run_id: request.params.run_id, text: text, truncated: !!truncated}}
        }, error || "", request.route);
    }
    function logCalls(): var { return calls.filter(call => call.method === "updates.readLog"); }
    function copyCalls(): var { return calls.filter(call => call.method === ClipApi.methods.selectionPublishText); }
    function acknowledgeCopy(request): void {
        Io.DaemonSessions.sessions["clip-daemon"].client.response(request.id, {
            protocol: ClipApi.protocol, version: ClipApi.version, ok: true, data: {}
        }, "", request.route);
    }
    function test_nowIsIndependentOfHistoryAndDoesNotClaimBootedState(): void {
        const root = fixture();
        const now = Date.now();
        const created = Math.floor(now / 1000) - 3 * 86400;
        root.barState.updates = {available: true, error: null, lanes: [{name: "delayed", ready: true,
            revision: "revision-123", base_hash: "base-456", created_at: created, auto_apply: false, system: "/nix/store/candidate"}],
            jobs: [{name: "system", operation: "check-delayed", status: "completed", phase: "ready", started_at: created, finished_at: created + 10, error: null},
                {name: "ai-tools", operation: "ai-update", status: "running", phase: "building", started_at: created, finished_at: null, error: null}]};
        reply(latest(), [entry("old-staged", "staged")]);
        verify(root.controller.selectedIsOverview);
        compare(root.controller.selectedRun, null);
        compare(root.controller.entries.length, 1);
        compare(root.controller.countLabel, "1 of 1 runs · read only");
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        const system = findChild(root, "updateLane:system");
        const tools = findChild(root, "updateLane:ai-tools");
        const candidate = findChild(root, "updateDeferredCandidate");
        compare(system.lane.status, "Ready · deferred candidate");
        compare(tools.lane.status, "Running · Building");
        compare(findChild(root, "updateLane:ai-tools-stale").lane.status, "Not reported");
        verify(system.lane.timing.startsWith("Last worker run"));
        verify(!candidate.visible);
        showPage(root, "system");
        verify(candidate.visible);
        compare(findChild(root, "updateCandidate:revision").modelData.value, "revision-123");
        compare(findChild(root, "updateCandidate:base").modelData.value, "base-456");
        compare(findChild(root, "updateCandidate:application").modelData.value, "Approval required");
        verify(findChild(root, "updateCandidate:waiting").modelData.value.startsWith("3 d"));
        root.barState.updates = Object.assign({}, root.barState.updates, {error: "Readiness is unreadable"});
        compare(findChild(root, "updateCandidateStatus").text, "Candidate status unavailable");
        compare(tools.lane.status, "Running · Building");
        root.barState.updates = Object.assign({}, root.barState.updates, {error: null,
            lanes: [Object.assign({}, root.barState.updates.lanes[0], {auto_apply: true})]});
        compare(findChild(root, "updateCandidate:application").modelData.value, "Automatic");
        compare(logCalls().length, 0);
        keyClick(Qt.Key_Tab);
        verify(root.content.detailsNavigation.browsing);
        compare(root.content.detailsNavigation.highlightedControl, null);
        keyClick(Qt.Key_Down);
        compare(root.controller.selectedRun.job.id, "old-staged");
        verify(!candidate.visible);
        compare(root.controller.selectedRun.outcome, "staged");
        root.barState.updates = {available: true, error: null, lanes: [{name: "delayed", ready: false}], jobs: []};
        compare(root.controller.selectedRun.outcome, "staged");
        keyClick(Qt.Key_Up);
        verify(root.controller.selectedIsOverview);
        compare(system.lane.status, "Not reported");
        verify(!system.lane.status.includes("staged"));
        const reads = calls.length;
        for (const [status, phase, ready, expected] of [
            ["running", "building", true, "Running · Building"],
            ["failed", "staged", true, "Failed"],
            ["interrupted", "staged", true, "Interrupted"],
            ["completed", "blocked", true, "Blocked"],
            ["completed", "staged", true, "Ready · deferred candidate"],
            ["completed", "staged", false, "Idle · last run staged for boot"],
            ["completed", "current", false, "Idle · last result: No changes"]
        ]) {
            root.barState.updates = {available: true, error: null, lanes: [{name: "delayed", ready: ready}],
                jobs: [{name: "system", status: status, phase: phase, operation: "run-delayed", started_at: created, finished_at: created + 10}]};
            compare(system.lane.status, expected);
        }
        compare(calls.length, reads);
        verify(root.controller.selectedIsOverview && root.content.listItem.listFocused);
        root.controller.filterText = "nothing matches";
        root.controller.refresh();
        reply(latest(), []);
        compare(root.controller.filteredResults.length, 1);
        verify(root.controller.selectedIsOverview);
        compare(root.controller.countLabel, "0 of 0 matching runs · read only");
        verify(calls.every(call => ["updates.queryHistory", "updates.getOverview", "bar.snapshot"].includes(call.method)));
    }
    function test_autoLogsQueueTheLatestSelectionAndCacheFailuresWithoutRetry(): void {
        const root = fixture();
        const runs = [entry("failed-auto", "failed"), entry("partial-auto", "partial"), entry("good-auto", "activated")];
        reply(latest(), runs);
        compare(logCalls().length, 0);
        focusFirstRun(root);
        keyClick(Qt.Key_Right);
        tryCompare(root.controller, "selectedLogLoading", true);
        compare(logCalls().length, 1);
        const first = logCalls()[0];
        keyClick(Qt.Key_Down);
        compare(root.controller.selectedRun.job.id, "partial-auto");
        verify(root.controller.selectedLogQueued);
        compare(findChild(root, "updateRunLogText").text, "Waiting to read log…");
        compare(logCalls().length, 1);
        logReply(first, "First run log", false);
        tryCompare(root.controller, "selectedLogLoading", true);
        compare(logCalls().length, 2);
        compare(logCalls()[1].params.run_id, "partial-auto");
        compare(root.controller.selectedLog, "");
        logReply(logCalls()[1], "", false, "Not permitted");
        compare(root.controller.selectedLogError, "Not permitted");
        keyClick(Qt.Key_Up);
        compare(root.controller.selectedLog, "First run log");
        keyClick(Qt.Key_Down);
        root.controller.refresh();
        reply(latest(), runs);
        wait(30);
        compare(root.controller.selectedLogError, "Not permitted");
        compare(logCalls().length, 2);
        tryVerify(() => root.content.detailsNavigation.commandButtons.some(button => button.accessKey === "V" && button.enabled));
        keyClick(Qt.Key_V, Qt.AltModifier);
        tryCompare(root.controller, "selectedLogLoading", true);
        const text = "ordinary <b>literal</b>\nerror: build failed\nwarning: retry later";
        logReply(logCalls()[2], text, true);
        compare(root.controller.selectedLog, text);
        compare(findChild(root, "updateLogSource").text, "Worker journal");
        compare(findChild(root, "updateLogLine:0").textFormat, Text.PlainText);
        compare(findChild(root, "updateLogLine:1").font.family, "monospace");
        compare(findChild(root, "updateLogLine:1").color, Ui.Theme.danger);
        compare(findChild(root, "updateLogLine:2").color, Ui.Theme.warning);
        verify(findChild(root, "updateLogLimit").text.includes("last 100 lines"));
        keyClick(Qt.Key_Down);
        wait(30);
        compare(logCalls().length, 3);
        keyClick(Qt.Key_Up);
        compare(root.controller.selectedLog, text);
        keyClick(Qt.Key_V, Qt.AltModifier);
        const late = logCalls().slice(-1)[0];
        root.controller.deactivateUi();
        logReply(late, "Too late", false);
        compare(root.controller.logCache.length, 0);
    }
    function test_runningLogIsInvalidatedAtCompletionAndCacheIsBounded(): void {
        const root = fixture();
        const runs = Array.from({length: 10}, (_, index) => entry("cache-" + index, "activated"));
        runs[0].outcome = "running";
        runs[0].job.status = "running";
        runs[0].job.phase = "building";
        runs[0].job.finished_at = null;
        reply(latest(), runs);
        focusFirstRun(root);
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        keyClick(Qt.Key_V, Qt.AltModifier);
        logReply(logCalls()[0], "Still building", false);
        compare(root.controller.selectedLog, "Still building");
        // A transport reply supplies a new immutable snapshot, not an in-place
        // mutation of the previously published JavaScript fixture.
        runs[0] = Object.assign({}, runs[0], {outcome: "failed",
            job: Object.assign({}, runs[0].job, {status: "failed", finished_at: 200})});
        root.controller.refresh();
        reply(latest(), runs);
        tryVerify(() => logCalls().length === 2);
        compare(root.controller.selectedLog, "");
        logReply(logCalls()[1], "error: terminal failure", false);
        compare(root.controller.selectedLog, "error: terminal failure");
        for (let index = 1; index < runs.length; ++index) {
            root.controller.selectedIndex = index + 1;
            verify(root.controller.perform("logs"));
            logReply(logCalls().slice(-1)[0], "Log " + index, false);
        }
        compare(root.controller.logCache.length, 8);
        verify(!root.controller.logCache.some(log => log.id === "cache-0"));
    }
    function test_componentGroupsAndCopiesPreserveFullVersions(): void {
        const root = fixture();
        const run = entry("copy-run", "partial");
        run.job.operation = "manual-rebuild";
        const before = "/nix/store/0123456789abcdef-nixos-system-host-26.05.1";
        const after = "/nix/store/fedcba9876543210-nixos-system-host-26.05.2";
        run.components = [
            {name: "NixOS", phase: "failed", changed: true, before: before, after: after, error: "Follow-up failed"},
            {name: "Changed", phase: "activated", changed: true, before: "1", after: "2", error: null},
            {name: "Unchanged", phase: "current", changed: false, before: "3", after: "3", error: null}
        ];
        reply(latest(), [run]);
        focusFirstRun(root);
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady && logCalls().length === 1);
        const rawLog = Array.from({length: 105}, (_, index) => index === 104 ? "error: raw log" : "line " + index).join("\n");
        logReply(logCalls()[0], rawLog, false);
        compare(findChild(root, "updateLogSource").text, "Rebuild log file");
        compare(findChild(root, "updateLogLine:0").text, "line 5");
        compare(findChild(root, "updateLogLine:99").text, "error: raw log");
        compare(findChild(root, "updateLogLine:100"), null);
        verify(findChild(root, "updateLogLimit").text.startsWith("Log truncated"));
        compare(findChild(root, "updateComponentCount").text, "2 of 3 components changed");
        compare(findChild(root, "updateComponentGroup:failed").title, "Failed · 1");
        compare(findChild(root, "updateComponentGroup:changed").title, "Changed · 1");
        compare(findChild(root, "updateComponentGroup:unchanged").title, "Unchanged · 1");
        compare(findChild(root, "updateComponent:NixOS").subtitle, "Failed · Changed before failure");
        keyClick(Qt.Key_C, Qt.AltModifier);
        tryVerify(() => copyCalls().length === 1);
        const summary = copyCalls()[0].params.text;
        verify(summary.startsWith(run.title + "\nRun: copy-run"));
        verify(summary.includes("Status / outcome:"));
        verify(summary.includes(before) && summary.includes(after));
        verify(summary.includes("Follow-up failed"));
        acknowledgeCopy(copyCalls()[0]);
        verify(root.controller.triggerDetailAction("copy-json"));
        const jsonCopy = copyCalls()[1];
        compare(JSON.parse(jsonCopy.params.text).components[0].after, after);
        acknowledgeCopy(jsonCopy);
        verify(root.controller.triggerDetailAction("copy-log"));
        compare(copyCalls()[2].params.text, rawLog);
        acknowledgeCopy(copyCalls()[2]);
        showPage(root, "changes");
        const button = findChild(root, "updateCopyComponent:NixOS");
        const scroll = findChild(root, "updateDetailsScroll");
        compare(findChild(root, "updateComponent:NixOS").modelData.componentIndex, 0);
        verify(!root.controller.copyComponent("another-run", 0));
        scroll.revealItem(button);
        wait(50);
        verify(button.visible && button.enabled);
        verify(button.mapToItem(scroll, 0, 0).y >= 0 && button.mapToItem(scroll, 0, button.height).y <= scroll.height, "copy command is in the viewport");
        mouseClick(button);
        tryVerify(() => copyCalls().length === 4);
        verify(copyCalls()[3].params.text.includes(before));
        verify(copyCalls()[3].params.text.includes(after));
        root.controller.errorText = "History error";
        Io.DaemonSessions.sessions["clip-daemon"].client.response(copyCalls()[3].id, null, "Clipboard unavailable", copyCalls()[3].route);
        compare(root.controller.copyError, "Clipboard unavailable");
        compare(root.controller.errorText, "History error");
        compare(Presentation.shortVersion(before), "host-26.05.1");
        compare(Presentation.shortVersion("/nix/store/abc-other-package"), "/nix/store/abc-other-package");
        compare(Presentation.shortVersion(null), "Unknown");
        verify(calls.every(call => ["updates.queryHistory", "updates.getOverview", "updates.readLog", "bar.snapshot", ClipApi.methods.selectionPublishText].includes(call.method)));
    }
    function overviewValue(): var {
        return {schema_version: 1, available: true, observed_at: 400, error: null,
            history_available: true, history_error: null, issue_total: 1,
            issues: [{run_id: "failed-overview", lane: "system", component: "manual-rebuild", incident: null, error: "Hook failed", failed_at: 200}],
            system: {active: "/nix/store/active", booted: "/nix/store/booted", profile: "/nix/store/staged", staged_for_next_boot: true,
                staged_since: 300, pending_transaction: false, queued: false, last_successful_check: 250, errors: []},
            baseline: {valid: true, approved_at: 300, revision: "rev", reasons: [], error: null},
            tools: [{name: "pi", installed_version: "1.0", phase: "current", last_successful_check: 280, last_activation: 270, error: null}],
            timers: [{unit: "nixos-update.timer", next_at: 500, last_at: 250}], timers_error: null};
    }
    function overviewReply(request, value): void {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(request.id, {
            protocol: Contract.protocol, version: Contract.version, ok: true, data: {overview: value}
        }, "", request.route);
    }
    function latestOverview(): var { return calls.filter(call => call.method === "updates.getOverview").slice(-1)[0]; }
    function test_nativeOverviewIssueNavigationAndStructuredRecovery(): void {
        const root = fixture();
        reply(latest(), []);
        overviewReply(latestOverview(), overviewValue());
        compare(root.controller.overviewLoading, false);
        compare(root.controller.overviewError, "");
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        const system = findChild(root, "updateSystemOverview");
        verify(!system.visible);
        showPage(root, "system");
        verify(system.visible);
        verify(system.rows.find(field => field.label === "Staging").value.startsWith("Staged for next boot since"));
        compare(system.rows.find(field => field.label === "Active").value, "/nix/store/active");
        compare(findChild(root, "updateInstalledTool:pi").modelData.last_successful_check, 280);
        compare(findChild(root, "updateTimer:nixos-update.timer").modelData.next_at, 500);
        showPage(root, "overview");
        const review = findChild(root, "updateReviewIssue:failed-overview");
        findChild(root, "updateDetailsScroll").revealItem(review);
        wait(50);
        mouseClick(review);
        tryCompare(root.controller, "runId", "failed-overview");
        compare(latest().params.run_id, "failed-overview");
        const run = entry("failed-overview", "partial");
        run.job.status = "failed";
        run.job.operation = "manual-rebuild";
        run.job.exit_code = 1;
        run.deployed = true;
        run.failed_stage = "activation-hook";
        run.issues = [{component: null, failed_at: 200, recovered_at: 300, recovered_run_id: "later-success"}];
        reply(latest(), [run]);
        tryVerify(() => root.content.detailsNavigation.contentReady && root.controller.selectedRun !== null);
        compare(root.controller.selectedRun.job.id, "failed-overview");
        const outcome = findChild(root, "updateRecordedOutcome");
        compare(outcome.rows.find(field => field.label === "Failed stage").value, "Activation hook");
        compare(outcome.rows.find(field => field.label === "Deployment recorded").value, "Yes");
        compare(outcome.rows[0].value, "Partial");
        verify(findChild(root, "updateRun:failed-overview").accessibleName.includes("Recovered"));
        keyClick(Qt.Key_C, Qt.AltModifier);
        tryVerify(() => copyCalls().length === 1);
        const copied = copyCalls()[0].params.text;
        verify(copied.includes("Failed stage: Activation hook") && copied.includes("Deployment recorded: Yes") && copied.includes("recovered"));
        acknowledgeCopy(copyCalls()[0]);
        verify(calls.every(call => ["updates.queryHistory", "updates.getOverview", "updates.readLog", "bar.snapshot", ClipApi.methods.selectionPublishText].includes(call.method)));
    }
    function test_overviewIssueReviewUsesTheSharedKeyboardCommandMenu(): void {
        const root = fixture();
        reply(latest(), []);
        overviewReply(latestOverview(), overviewValue());
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        keyClick(Qt.Key_Tab);
        verify(root.content.detailsNavigation.browsing);
        compare(root.content.detailsNavigation.highlightedControl, null);
        const commands = root.content.detailsNavigation.contentCommands.filter(item => !item.accessKey || item.includeInCommandMenu);
        const reviewIndex = commands.findIndex(item => item.accessibleName === "Review failure: manual-rebuild");
        verify(reviewIndex >= 0);
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => root.content.detailsNavigation.commandMenuOpen);
        for (let i = 0; i < reviewIndex; ++i) keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        tryCompare(root.controller, "runId", "failed-overview");
        compare(latest().params.run_id, "failed-overview");
    }
    function test_completionDispatchRetiresOnlyTheOwnedReader(): void {
        const root = fixture();
        reply(latest(), [entry("retained", "staged")]);
        focusFirstRun(root);
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        keyClick(Qt.Key_V, Qt.AltModifier);
        keyClick(Qt.Key_F5);
        const history = root.controller.ownedRequest;
        const overview = root.controller.overviewRequest;
        const log = root.controller.logRequest;
        verify(!!history && !!overview && !!log);
        root.controller.finish("", null, "Unowned error");
        root.controller.finish("foreign", null, "Unowned error");
        compare(root.controller.ownedRequest, history);
        compare(root.controller.overviewRequest, overview);
        compare(root.controller.logRequest, log);
        root.controller.finish(log, null, "Log unavailable");
        compare(root.controller.logRequest, "");
        compare(root.controller.selectedLogError, "Log unavailable");
        compare(root.controller.ownedRequest, history);
        compare(root.controller.overviewRequest, overview);
        root.controller.finish(log, null, "Duplicate error");
        compare(root.controller.selectedLogError, "Log unavailable");
        reply(latest(), [entry("replacement", "staged")]);
        compare(root.controller.loading, false);
        compare(root.controller.entries[0].job.id, "replacement");
        overviewReply(latestOverview(), overviewValue());
        tryVerify(() => !!root.controller.overviewRequest && root.controller.overviewRequest !== overview); // queued F5 read
        const pending = root.controller.overviewRequest;
        root.controller.finish(overview, null, "Duplicate overview error");
        compare(root.controller.overviewRequest, pending);
        compare(root.controller.overviewError, "");
    }
    function test_overviewRefreshDuringAReadGetsOneFollowup(): void {
        const root = fixture();
        const first = latestOverview();
        root.controller.requestOverview();
        root.controller.requestOverview();
        compare(calls.filter(call => call.method === "updates.getOverview").length, 1);
        overviewReply(first, overviewValue());
        tryVerify(() => calls.filter(call => call.method === "updates.getOverview").length === 2);
        const newer = overviewValue();
        newer.observed_at = 450;
        overviewReply(latestOverview(), newer);
        wait(0);
        compare(calls.filter(call => call.method === "updates.getOverview").length, 2);
        compare(root.controller.overview.observed_at, 450);
        compare(root.controller.overviewRefreshPending, false);
    }
    function test_overviewFailuresAndLateRepliesCannotReplacePublishedStateOrHistory(): void {
        const root = fixture();
        reply(latest(), [entry("retained", "staged")]);
        const first = latestOverview();
        overviewReply(first, overviewValue());
        root.controller.errorText = "Independent history error";
        root.controller.requestOverview();
        const second = latestOverview();
        const bad = overviewValue();
        bad.timers[0].next_at = -1;
        overviewReply(second, bad);
        compare(root.controller.overviewError, "Invalid update overview reply");
        compare(root.controller.overview.timers[0].next_at, 500);
        compare(root.controller.errorText, "Independent history error");
        overviewReply(first, bad);
        compare(root.controller.overview.timers[0].next_at, 500);
        root.controller.requestOverview();
        const late = latestOverview();
        root.controller.deactivateUi();
        const replacement = overviewValue();
        replacement.issue_total = 0;
        replacement.issues = [];
        overviewReply(late, replacement);
        compare(root.controller.overview.issue_total, 1);
        compare(root.controller.entries[0].job.id, "retained");
        const invalidRun = entry("invalid", "failed");
        invalidRun.components = [{name: "pi", phase: "failed", changed: false, before: null, after: null, error: "bad", incident: "bad\nkey"}];
        root.controller.activateUi("");
        reply(latest(), [invalidRun]);
        compare(root.controller.errorText, "Invalid update history reply");
        compare(root.controller.entries[0].job.id, "retained");
        invalidRun.components[0].incident = "pi:build:fingerprint";
        root.controller.refresh();
        reply(latest(), [invalidRun]);
        compare(root.controller.errorText, "");
        compare(root.controller.entries[0].components[0].incident, "pi:build:fingerprint");
        const rejectedRun = Object.assign({}, invalidRun, {issues: [{component: 2, failed_at: 200, recovered_at: null, recovered_run_id: null}]});
        root.controller.refresh();
        reply(latest(), [rejectedRun]);
        compare(root.controller.errorText, "Invalid update history reply");
        compare(root.controller.entries[0].issues, undefined);
    }
    function test_taskTabsGearTransactionsAndFreshnessEvidence(): void {
        const root = fixture();
        reply(latest(), [entry("recorded", "staged")]);
        const value = overviewValue();
        value.git = {available: true, path: "/configuration", revision: "a".repeat(40), branch: "main", upstream: "origin/main",
            ahead: 2, behind: 4, dirty: true, shallow: false, observed_at: 390, target_observed_at: null, error: null};
        value.tools[0].freshness = {latest_version: "1.0", source: "vendor stable", published_at: null, origin: "vendor",
            comparison: "rebuild", stale: true, held: true, hold_since: 320, hold_reason: "Deliberate rollback"};
        overviewReply(latestOverview(), value);
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        compare(root.controller.detailsTab, "overview");
        verify(root.controller.detailTabs.every(tab => Ui.MaterialIcons.name(tab.icon) === tab.icon));
        verify(findChild(root, "updateArea:applications").modelData.value.includes("not reported"));
        verify(findChild(root, "updateArea:git").modelData.value.includes("Diverged"));
        verify(!root.content.detailsNavigation.contentCommands.some(command => command.accessibleName.startsWith("Inspect ")));
        const reads = calls.length;
        showPage(root, "git");
        const git = findChild(root, "updateGitOverview");
        verify(git.visible);
        compare(git.rows.find(row => row.label === "Remote checked").value, "Not recorded");
        showPage(root, "ai");
        const tool = findChild(root, "updateInstalledTool:pi");
        verify(tool.visible);
        compare(tool.rows.find(row => row.label === "Latest known").value, "1.0");
        verify(tool.rows.find(row => row.label === "Comparison").value.includes("packaging update"));
        verify(tool.rows.find(row => row.label === "Comparison").value.startsWith("Last known:"));
        showPage(root, "applications");
        verify(findChild(root, "updateApplicationsOverview").visible);
        showPage(root, "system");
        verify(findChild(root, "updateSystemOverview").visible);
        compare(calls.length, reads, "tabs do not fetch, check or install");
        keyClick(Qt.Key_Tab);
        compare(root.content.detailsNavigation.highlightedControl, null);
        const gear = findChild(root, "fieldTrailingAction");
        mouseClick(gear);
        tryVerify(() => root.controller.settingsOpen && root.content.detailsNavigation.browsing);
        compare(root.controller.pageKey, "settings");
        compare(root.controller.detailTabs.length, 0);
        compare(root.content.listItem.listOptionsComponent, null);
        compare(calls.length, reads);
        keyClick(Qt.Key_T, Qt.AltModifier);
        tryVerify(() => root.content.detailsNavigation.highlightedControl === findChild(root, "updateLaneFilter"));
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        compare(root.controller.laneFilter, "");
        // Leaving through the gear discards rather than saving the proposed filter.
        mouseClick(gear);
        tryCompare(root.controller, "detailsOpen", false);
        compare(root.controller.laneFilter, "");
        compare(calls.length, reads);
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => !root.controller.settingsOpen && root.controller.detailsOpen);
        tryCompare(root.controller, "detailsTab", "system");
        keyClick(Qt.Key_Down);
        tryCompare(root.controller, "detailsTab", "summary");
        showPage(root, "changes");
        keyClick(Qt.Key_Up);
        tryCompare(root.controller, "detailsTab", "system");
        keyClick(Qt.Key_Down);
        tryCompare(root.controller, "detailsTab", "changes");
        compare(calls.length, reads);
        root.controller.requestOverview();
        const invalid = overviewValue();
        invalid.tools[0].freshness = Object.assign({}, value.tools[0].freshness, {comparison: "guessed"});
        overviewReply(latestOverview(), invalid);
        compare(root.controller.overviewError, "Invalid update overview reply");
        compare(root.controller.overview.git.behind, 4);
        root.controller.requestOverview();
        overviewReply(latestOverview(), overviewValue());
        compare(root.controller.overviewError, "");
        compare(root.controller.overview.git, undefined, "older worker omits the optional evidence");
        verify(Presentation.toolFreshness(root.controller.overview.tools[0]).includes("not reported"));
    }
    function test_applicationInventoryIsReadOnlyAndRejectsMalformedRefresh(): void {
        const root = fixture();
        reply(latest(), []);
        const value = overviewValue();
        value.applications = {available: true, active_system: "/nix/store/active-system", observed_at: 390,
            total: 3, error: null, packages: [
                {name: "editor", scope: "system", version: "1.2.3"},
                {name: "local-tool", scope: "user:test", version: null}
            ]};
        overviewReply(latestOverview(), value);
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        verify(findChild(root, "updateArea:applications").modelData.value.includes("3 packages · active generation"));
        const reads = calls.length;
        showPage(root, "applications");
        const inventory = findChild(root, "updateApplicationsOverview");
        verify(inventory.visible);
        const editor = findChild(inventory, "updateApplication:system:editor");
        const versionless = findChild(inventory, "updateApplication:user:test:local-tool");
        compare(findChild(editor, "updateApplicationLocal").text, "1.2.3");
        compare(findChild(versionless, "updateApplicationLocal").text, "—");
        compare(findChild(editor, "updateApplicationLatest").text, "—");
        const feedback = findChild(root.content.listItem, "feedbackText");
        const explanation = findChild(inventory, "updateApplicationExplanation");
        compare(explanation.text, "");
        const height = inventory.height;
        mouseClick(findChild(inventory, "sectionHeadingHelp"));
        tryCompare(explanation, "text", inventory.helpText);
        tryVerify(() => feedback.text.includes("latest known upstream releases"));
        compare(inventory.height, height, "Help uses the status bar, never a growing row");
        mouseClick(findChild(editor, "updateApplicationStatus"));
        tryCompare(feedback, "text", "editor: no release source configured.");
        mouseClick(findChild(versionless, "updateApplicationStatus"));
        tryCompare(feedback, "text", "local-tool: no release source configured.");
        compare(inventory.height, height);
        showPage(root, "system");
        compare(explanation.text, "");
        showPage(root, "applications");
        keyClick(Qt.Key_Tab);
        compare(root.content.detailsNavigation.highlightedControl, null);
        const commands = root.content.detailsNavigation.contentCommands.filter(item => !item.accessKey || item.includeInCommandMenu);
        const statusIndex = commands.findIndex(item => item.accessibleName === "Version status: editor");
        verify(statusIndex >= 0);
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => root.content.detailsNavigation.commandMenuOpen);
        for (let i = 0; i < statusIndex; ++i) keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        tryCompare(feedback, "text", "editor: no release source configured.");
        compare(root.content.detailsNavigation.highlightedControl, null);
        keyClick(Qt.Key_PageDown);
        compare(calls.length, reads, "reading and scrolling inventory cannot check or install packages");
        root.controller.requestOverview();
        const invalid = JSON.parse(JSON.stringify(value));
        invalid.applications.packages[0].version = 123;
        overviewReply(latestOverview(), invalid);
        compare(root.controller.overviewError, "Invalid update overview reply");
        compare(findChild(inventory, "updateApplication:system:editor").modelData.version, "1.2.3");
        root.controller.requestOverview();
        const unavailable = overviewValue();
        unavailable.applications = {available: false, active_system: null, observed_at: null, total: 0,
            packages: [], error: "Active generation has no application inventory"};
        overviewReply(latestOverview(), unavailable);
        compare(findChild(inventory, "updateApplicationUnavailable").text, unavailable.applications.error);
        compare(findChild(inventory, "updateApplication:system:editor"), null);
        compare(explanation.text, "");
        mouseClick(findChild(inventory, "sectionHeadingHelp"));
        verify(explanation.text.length > 0);
        root.controller.deactivateUi();
        compare(explanation.text, "");
    }
    function test_applicationReleaseVersionsKeepStaleAndUnsupportedEvidenceDistinct(): void {
        const root = fixture();
        reply(latest(), []);
        const value = overviewValue();
        const release = {version: "2.0", source: "https://api.github.com/repos/example/editor/releases/latest",
            checked_at: 390, attempted_at: 390, stale: false, error: null};
        value.applications = {available: true, active_system: "/nix/store/active-system", observed_at: 400,
            total: 3, error: null, packages: [
                {name: "editor", scope: "system", version: "1.0", release: release},
                {name: "stale", scope: "system", version: "1.0", release: Object.assign({}, release, {stale: true, error: "HTTP 429", attempted_at: 400})},
                {name: "unchecked", scope: "system", version: null, release: Object.assign({}, release, {version: null, checked_at: null, attempted_at: null, stale: true})}
            ]};
        overviewReply(latestOverview(), value);
        root.controller.openDetails();
        tryVerify(() => root.content.detailsNavigation.contentReady);
        showPage(root, "applications");
        const reads = calls.length;
        const inventory = findChild(root, "updateApplicationsOverview");
        const editor = findChild(inventory, "updateApplication:system:editor");
        const stale = findChild(inventory, "updateApplication:system:stale");
        const unchecked = findChild(inventory, "updateApplication:system:unchecked");
        compare(findChild(editor, "updateApplicationLocal").text, "1.0");
        compare(findChild(editor, "updateApplicationLatest").text, "2.0");
        compare(findChild(stale, "updateApplicationLatest").text, "2.0");
        compare(findChild(unchecked, "updateApplicationLatest").text, "—");
        const feedback = findChild(root.content.listItem, "feedbackText");
        mouseClick(findChild(editor, "updateApplicationStatus"));
        tryCompare(feedback, "text", "editor: latest release 2.0.");
        mouseClick(findChild(stale, "updateApplicationStatus"));
        tryCompare(feedback, "text", "stale: last known 2.0; check failed.");
        compare(findChild(stale, "updateApplicationStatus").icon, "warning");
        mouseClick(findChild(unchecked, "updateApplicationStatus"));
        tryCompare(feedback, "text", "unchecked: latest release not checked.");
        root.content.listItem.focusList();
        keyClick(Qt.Key_Tab);
        compare(root.content.detailsNavigation.highlightedControl, null);
        compare(calls.length, reads, "version disclosure cannot request a network check or update");
        for (const patch of [{version: 123}, {checked_at: null}, {source: "file:///tmp/version"}, {error: "failed", stale: false}]) {
            root.controller.requestOverview();
            const invalid = JSON.parse(JSON.stringify(value));
            invalid.applications.packages[0].release = Object.assign({}, release, patch);
            overviewReply(latestOverview(), invalid);
            compare(root.controller.overviewError, "Invalid update overview reply");
            compare(findChild(editor, "updateApplicationLatest").text, "2.0");
        }
    }
    function test_globalSettingsSurvivePrunedSelectionButExactLinksOpenTheRun(): void {
        const root = fixture();
        reply(latest(), [entry("old", "current")]);
        overviewReply(latestOverview(), overviewValue());
        root.controller.selectedIndex = 1;
        root.controller.openSettings("");
        tryVerify(() => root.content.detailsNavigation.contentReady && root.content.detailsNavigation.browsing);
        root.controller.refresh();
        reply(latest(), []);
        tryVerify(() => root.controller.selectedIsOverview);
        verify(root.controller.settingsOpen && root.controller.detailsOpen);
        compare(root.controller.viewMemory.key, "updates::settings");
        root.controller.openRun("exact");
        reply(latest(), [entry("exact", "current")]);
        tryVerify(() => !root.controller.settingsOpen && root.controller.detailsOpen);
        compare(root.controller.selectedRun.job.id, "exact");
        compare(root.controller.detailsTab, "summary");
    }
    function test_toolEvidenceHelpAndCopyKeepPlainCompleteDiagnostics(): void {
        const root = fixture();
        reply(latest(), []);
        const value = overviewValue();
        value.tools[0].error = "Verification <b>failed</b>\nFull diagnostic";
        overviewReply(latestOverview(), value);
        root.controller.openDetails();
        tryVerify(() => root.content.detailsNavigation.contentReady);
        showPage(root, "ai");
        const tool = findChild(root, "updateInstalledTool:pi");
        mouseClick(findChild(tool, "formFieldHelp"));
        verify(tool.helpOpen);
        const support = findChild(tool, "formFieldSupport");
        compare(support.textFormat, Text.PlainText);
        verify(support.text.includes(value.tools[0].error));
        mouseClick(findChild(tool, "formFieldCopy"));
        tryVerify(() => copyCalls().length === 1);
        verify(copyCalls()[0].params.text.includes(value.tools[0].error));
        verify(copyCalls()[0].params.text.includes("1970-01-01T00:04:40.000Z"));
        acknowledgeCopy(copyCalls()[0]);
        root.content.listItem.focusList();
        keyClick(Qt.Key_Tab);
        verify(root.content.detailsNavigation.browsing);
        compare(root.content.detailsNavigation.highlightedControl, null);
    }
    function test_freshnessDoesNotInventReleaseDistanceOrRemoteChecks(): void {
        compare(Presentation.toolFreshness({installed_version: "1.0", freshness: {latest_version: "1.0"}}), "Comparison not reported");
        compare(Presentation.gitSummary({available: true, upstream: "origin/main", shallow: true, ahead: 0, behind: 0}), "Commit distance unavailable");
        compare(Presentation.gitSummary({available: true, upstream: null}), "No tracked upstream");
        verify(Presentation.gitSummary({available: true, upstream: "origin/main", shallow: false, ahead: 0, behind: 0}).includes("cached"));
        compare(Presentation.systemSummary(null, null), "Release comparison not reported");
        const tool = {freshness: {comparison: "newer", stale: false}};
        compare(Presentation.toolsSummary([tool, {}]), "1 of 2 tools have updates · 1 unknown");
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
