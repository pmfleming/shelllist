pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "../../clipboard/ClipApi.js" as ClipApi
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
    function focusFirstRun(root): void {
        root.controller.selectedIndex = 1;
        root.content.listItem.focusList();
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
        verify(calls.every(call => ["updates.queryHistory", "updates.readLog", "bar.snapshot"].includes(call.method)));
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
        focusFirstRun(root);
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
        root.controller.filterText = "nothing matches";
        root.controller.refresh();
        reply(latest(), []);
        compare(root.controller.filteredResults.length, 1);
        verify(root.controller.selectedIsOverview);
        compare(root.controller.countLabel, "0 of 0 matching runs · read only");
        verify(calls.every(call => ["updates.queryHistory", "bar.snapshot"].includes(call.method)));
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
        verify(calls.every(call => ["updates.queryHistory", "updates.readLog", "bar.snapshot", ClipApi.methods.selectionPublishText].includes(call.method)));
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
