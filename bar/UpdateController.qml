import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "BarProtocol.generated.js" as Contract
import "UpdatePresentation.js" as Presentation
import "UpdateValidation.js" as Validation
import "UpdateHistory.js" as History

Ui.ProviderChooserController {
    id: controller
    property BarController barController: null
    property string errorText: ""
    property string copyError: ""
    property string warningText: ""
    property string warningBrief: ""
    property int total: 0
    property double nowMs: Date.now()
    property string calendarDay: ""
    onNowMsChanged: {
        const day = History.day(nowMs / 1000);
        if (calendarDay && calendarDay !== day && uiActive && /(^|\s|:)(today|yesterday)(\s|$)/i.test(filterText)) scheduleRefresh();
        calendarDay = day;
    }
    property string laneFilter: ""
    property string outcomeFilter: ""
    property bool collapseRoutine: true
    property bool settingsOpen: false
    property string detailsTab: "overview"
    signal settingsFieldRequested(string field)
    readonly property var detailTabs: settingsOpen ? [] : selectedIsOverview ? [
        {value: "overview", label: qsTr("Overview"), icon: "dashboard"},
        {value: "git", label: qsTr("Local Git"), icon: "account_tree"},
        {value: "ai", label: qsTr("AI tools"), icon: "auto_awesome"},
        {value: "applications", label: qsTr("Applications"), icon: "apps"},
        {value: "system", label: qsTr("System"), icon: "computer"}
    ] : selectedRun ? [
        {value: "summary", label: qsTr("Summary"), icon: "history"},
        {value: "changes", label: qsTr("Changes"), icon: "view_list"},
        {value: "log", label: qsTr("Log"), icon: "article"}
    ] : []
    readonly property string pageKey: settingsOpen ? "settings" : detailsTab
    readonly property string filterDescription: runId ? qsTr("Exact run · history filters bypassed")
        : (laneFilter ? Presentation.label(laneFilter) : qsTr("All jobs")) + " · "
            + (outcomeFilter ? Presentation.label(outcomeFilter) : qsTr("All outcomes"))
    property var expandedQuietIds: []
    property int foldedCount: 0
    readonly property bool historyFiltered: !!filterText.trim() || !!laneFilter || !!outcomeFilter
    readonly property string queryKey: JSON.stringify([filterText, laneFilter, outcomeFilter, runId])
    property string publishedQuery: ""
    property string publishedRevision: ""
    property var publishedAnchors: []
    property var historyWindow: null
    readonly property bool canLoadMore: !!cursor && !loading && publishedQuery === queryKey
    readonly property var selectedQuietGroup: selectedResult ? selectedResult.metadata.quietGroup || null : null
    readonly property string countLabel: publishedQuery !== queryKey && entries.length ? qsTr("Showing previous results")
        : (historyFiltered ? qsTr("%1 of %2 matching runs").arg(entries.length).arg(total) : qsTr("%1 of %2 runs").arg(entries.length).arg(total))
            + (foldedCount ? qsTr(" · %1 folded").arg(foldedCount) : "") + qsTr(" · read only")
    property string coverage: ""
    property var overview: null
    property string overviewRequest: ""
    property bool overviewLoading: false
    property bool overviewRefreshPending: false
    property string overviewError: ""
    property bool available: false
    property bool loading: false
    property string cursor: ""
    property string runId: ""
    property bool missingRun: false
    property var entries: []
    property string ownedRequest: ""
    property string logRequest: ""
    property string logRun: ""
    property string logVersion: ""
    // Invocation-local, bounded cache. Failed reads are cached too: browsing or
    // history refresh must not create an automatic retry loop.
    property var logCache: []
    readonly property var selectedLogRecord: selectedRun ? logCache.find(log => log.id === selectedRun.job.id && log.version === runLogVersion(selectedRun)) || null : null
    readonly property bool selectedLogLoading: !!selectedRun && selectedRun.job.id === logRun && !!logRequest
    readonly property bool selectedLogQueued: uiActive && detailsOpen && !!selectedRun && !selectedLogRecord && !!logRequest
        && selectedRun.job.id !== logRun && ["failed", "partial"].includes(selectedRun.outcome)
    readonly property string selectedLogError: selectedLogRecord ? selectedLogRecord.error : ""
    readonly property string selectedLog: selectedLogRecord ? selectedLogRecord.text : ""
    readonly property bool selectedIsOverview: !!selectedResult && selectedResult.metadata.overview === true
    readonly property var currentState: barController ? barController.updates : null
    property alias backend: backend
    readonly property var selectedRun: selectedResult && selectedResult.metadata.run ? selectedResult.metadata.run : null
    providerRankedResults: true
    closeDetailsWithoutSelection: true
    sharedScreenshotEnabled: true
    filterRefreshDelay: 180
    scheduledRefreshDelay: 120
    provider: Core.Provider {
        providerId: "updates"
        displayName: qsTr("Updates")
        function execute(request: var): bool { return controller.perform(request.actionId); }
    }
    viewMemory: Ui.ChooserMemory {
        controller: controller
        key: controller.settingsOpen ? "updates::settings" : controller.selectedResult ? controller.selectedResult.key : ""
        tab: controller.pageKey
        initialTab: controller.selectedIsOverview ? "overview" : "summary"
        tabs: controller.settingsOpen ? ["settings"] : controller.detailTabs.length ? controller.detailTabs.map(item => item.value) : ["summary"]
        onRestoreRequested: function(open, tab) {
            if (!controller.settingsOpen) controller.detailsTab = tab;
            controller.detailsOpen = open;
        }
    }
    function selectDetailsTab(value: string): void {
        if (navigationBlocked || settingsOpen || !detailTabs.some(tab => tab.value === value)) return;
        detailsClosing();
        viewMemory.synchronize();
        detailsTab = value;
        viewMemory.synchronize();
    }
    function cycleDetailsTab(backwards: bool): bool {
        if (settingsOpen || detailTabs.length < 2) return false;
        selectDetailsTab(tabAfter(detailTabs.map(tab => tab.value), detailsTab, backwards));
        return true;
    }
    function openSettings(field: string): void {
        if (!uiActive || navigationBlocked) return;
        detailsClosing();
        viewMemory.synchronize();
        settingsOpen = true;
        detailsOpen = true;
        viewMemory.synchronize();
        focusDetailsRequested();
        if (field) settingsFieldRequested(field);
    }
    function toggleSettings(): void {
        if (settingsOpen && detailsOpen) closeDetails();
        else openSettings("");
    }
    function closeDetails(): void {
        detailsClosing();
        viewMemory.synchronize();
        detailsOpen = false;
    }
    function openDetails(): void {
        if (!hasSelection) return;
        if (settingsOpen) detailsClosing();
        viewMemory.synchronize();
        settingsOpen = false;
        detailsOpen = true;
        viewMemory.synchronize();
    }
    function activateUi(workspaceId: string): void {
        activateUiState(workspaceId);
        nowMs = Date.now();
        publishResults();
        refresh();
    }
    onUiActiveChanged: if (!uiActive) { retireHistory(); overviewRequest = ""; overviewLoading = false; overviewRefreshPending = false; logRequest = ""; loading = false; logCache = []; }
    onSelectedRunChanged: Qt.callLater(autoReadLog)
    onDetailsOpenChanged: Qt.callLater(autoReadLog)
    onLogRequestChanged: Qt.callLater(autoReadLog)
    onNavigationBlockedChanged: if (!navigationBlocked) Qt.callLater(autoReadLog)
    onFilterTextChanged: { runId = ""; expandedQuietIds = []; retireHistory(); }
    onCollapseRoutineChanged: publishResults()
    Timer {
        id: historyDeadline
        interval: 15000
        onTriggered: controller.failHistory(qsTr("History read timed out; previous results retained"))
    }
    Timer {
        interval: controller.selectedRun && Presentation.isRunning(controller.selectedRun) && controller.detailsOpen ? 1000 : 30000
        repeat: true
        running: controller.uiActive
        onTriggered: controller.nowMs = Date.now()
    }
    function openRun(id: string): void {
        if (!/^[A-Za-z0-9][A-Za-z0-9-]{0,159}$/.test(id)) return;
        filterText = "";
        runId = id;
        missingRun = false;
        detailsOpen = false;
        if (uiActive) refresh();
    }
    function refresh(): void { requestPage(false); requestOverview(); }
    function requestOverview(): void {
        if (!uiActive || !backend.ready) return;
        if (overviewRequest) { overviewRefreshPending = true; return; }
        overviewRefreshPending = false;
        overviewRequest = backend.nextRequestId("update-overview");
        overviewLoading = true;
        overviewError = "";
        if (!backend.call(overviewRequest, "updates.getOverview", {})) overviewLoading = false;
    }
    function reviewIssue(id: string): void {
        if (uiActive && !navigationBlocked) openRun(id);
    }
    function setHistoryFilter(kind: string, value: string): void {
        if (!uiActive || navigationBlocked) return;
        if (!runId && ((kind === "lane" && laneFilter === value) || (kind === "outcome" && outcomeFilter === value))) return;
        if (kind === "lane" && ["", "system", "ai-tools", "ai-tools-stale"].includes(value)) laneFilter = value;
        else if (kind === "outcome" && ["", "problems", "running", "current", "activated", "staged", "ready", "queued", "failed", "partial", "blocked", "interrupted", "available", "skipped", "approved", "completed"].includes(value)) outcomeFilter = value;
        else return;
        runId = "";
        missingRun = false;
        expandedQuietIds = [];
        selectFirst();
        refresh();
    }
    function retireHistory(): void {
        ownedRequest = "";
        historyWindow = null;
        loading = false;
        historyDeadline.stop();
    }
    function loadMore(): void { if (canLoadMore) requestPage(true); }
    function requestPage(append: bool): void {
        if (!uiActive || !backend.ready) return;
        const retain = publishedQuery === queryKey && !runId;
        const anchors = retain ? [selectedRun ? selectedRun.job.id : "", entries.length ? entries[entries.length - 1].job.id : ""].filter(Boolean) : [];
        historyWindow = {key: queryKey, append: append, anchors: append ? publishedAnchors : [...new Set(anchors)],
            entries: append ? entries.slice() : [], revision: append ? publishedRevision : "", total: append ? total : -1,
            retainThrough: -1, target: retain ? entries.length : 0, pages: 0, retried: false, diagnostic: "", cursor: append ? cursor : ""};
        loading = true;
        errorText = "";
        historyDeadline.restart();
        sendHistoryPage();
    }
    function sendHistoryPage(): void {
        if (!historyWindow || !uiActive) return;
        ownedRequest = backend.nextRequestId("update-history");
        const sent = backend.call(ownedRequest, "updates.queryHistory", {query: runId ? "" : filterText, cursor: historyWindow.cursor || null,
            run_id: runId || null, limit: 50, lane: runId ? null : laneFilter || null, outcome: runId ? null : outcomeFilter || null, anchor_ids: historyWindow.anchors});
        if (!sent && ownedRequest) failHistory(qsTr("Update history read could not be sent"));
    }
    function restartHistoryWindow(): bool {
        if (!historyWindow || historyWindow.retried) return false;
        // One bounded restart from page one, never append across revisions.
        historyWindow = Object.assign({}, historyWindow, {append: false, entries: [], revision: "", total: -1, retainThrough: -1,
            target: Math.max(entries.length + (historyWindow.append ? 50 : 0), historyWindow.entries.length),
            anchors: [...new Set([selectedRun ? selectedRun.job.id : "", entries.length ? entries[entries.length - 1].job.id : ""].filter(Boolean))],
            retried: true, diagnostic: "", cursor: ""});
        sendHistoryPage();
        return true;
    }
    function finish(id: string, envelope: var, transportError: string): void {
        // Dispatch only nonempty, owned identities; each reader retires itself.
        if (!uiActive || !id) return;
        switch (id) {
        case overviewRequest: finishOverview(envelope, transportError); break;
        case logRequest: finishLog(envelope, transportError); break;
        case ownedRequest: finishHistory(envelope, transportError); break;
        }
    }
    function finishOverview(envelope: var, transportError: string): void {
        overviewRequest = "";
        overviewLoading = false;
        if (overviewRefreshPending) { overviewRefreshPending = false; Qt.callLater(requestOverview); }
        overviewError = backend.responseError(envelope, transportError, qsTr("Update overview unavailable"));
        if (overviewError) return;
        const value = envelope.data ? envelope.data.overview : null;
        if (!Validation.overview(value)) { overviewError = qsTr("Invalid update overview reply"); return; }
        overview = value;
    }
    function finishLog(envelope: var, transportError: string): void {
        logRequest = "";
        const failure = backend.responseError(envelope, transportError, qsTr("Update log unavailable"));
        if (failure) { cacheLog("", failure, false); return; }
        const log = envelope.data ? envelope.data.log : null;
        if (!log || log.run_id !== logRun || typeof log.text !== "string" || log.text.length > 32768 || typeof log.truncated !== "boolean") {
            cacheLog("", qsTr("Invalid update log reply"), false); return;
        }
        cacheLog(log.text, "", log.truncated);
    }
    function failHistory(message: string): void {
        retireHistory();
        errorText = message;
    }
    function finishHistory(envelope: var, transportError: string): void {
        if (!historyWindow || historyWindow.key !== queryKey) return;
        ownedRequest = "";
        const failure = backend.responseError(envelope, transportError, qsTr("Update history unavailable"));
        if (failure) {
            if (envelope && envelope.error && envelope.error.code === "update-history-cursor-stale" && restartHistoryWindow()) return;
            failHistory(failure); return;
        }
        const page = envelope.data ? envelope.data.history : null;
        if (!Validation.historyPage(page)) {
            failHistory(qsTr("Invalid update history reply")); return;
        }
        if (!page.available) {
            retireHistory();
            available = page.available;
            cursor = "";
            errorText = (page.error || qsTr("Update history has not been published"))
                + (entries.length > 0 ? " · " + qsTr("Showing cached runs") : "");
            return;
        }
        if (runId && !page.entries.length && page.error) {
            retireHistory();
            warningText = page.error;
            warningBrief = qsTr("Requested run could not be read");
            return;
        }
        if (runId && !page.entries.length) {
            retireHistory();
            runId = "";
            missingRun = true;
            refresh();
            return;
        }
        if (runId && (page.entries.length !== 1 || page.entries[0].job.id !== runId)) {
            failHistory(qsTr("Update history reply targets another run")); return;
        }
        stageHistoryPage(page);
    }
    function stageHistoryPage(page: var): void {
        const window = historyWindow;
        if (window.revision && window.revision !== page.revision) {
            if (restartHistoryWindow()) return;
            failHistory(qsTr("Update history kept changing; refresh again")); return;
        }
        const next = window.entries.concat(page.entries);
        if (new Set(next.map(entry => entry.job.id)).size !== next.length) {
            failHistory(qsTr("Duplicate update history identities")); return;
        }
        if (page.total < next.length || (window.total >= 0 && window.total !== page.total)
                || (window.retainThrough >= 0 && window.retainThrough !== (page.retain_through || 0))
                || (page.cursor && (!page.entries.length || page.cursor === window.cursor || next.length >= page.total))
                || (!page.cursor && next.length !== page.total) || ++window.pages > 128) {
            failHistory(qsTr("Invalid update history continuation")); return;
        }
        window.entries = next;
        window.revision = page.revision;
        window.total = page.total;
        window.retainThrough = page.retain_through || 0;
        window.cursor = page.cursor || "";
        window.diagnostic = page.error || window.diagnostic;
        if (!window.append && window.cursor && next.length < Math.max(window.target, window.retainThrough)) { sendHistoryPage(); return; }
        const preserve = publishedQuery === queryKey;
        publishedQuery = queryKey;
        publishedRevision = page.revision;
        publishedAnchors = window.anchors;
        const diagnostic = window.diagnostic;
        retireHistory();
        entries = next;
        total = page.total;
        available = page.available;
        cursor = page.cursor || "";
        coverage = page.coverage;
        // The wire diagnostics are capped and may contain multi-line/source errors,
        // so do not invent an unreadable-record count by splitting the string.
        warningText = diagnostic || (missingRun ? qsTr("The requested run is no longer retained. Showing recent updates.") : "");
        warningBrief = diagnostic ? qsTr("Some update history could not be read") : warningText;
        publishResults(preserve);
        if (runId && entries.length) { selectedIndex = filteredResults.findIndex(result => result.id === runId); openDetails(); }
    }
    function publishResults(preserve: var): void {
        const selectedId = selectedResult ? selectedResult.id : "";
        const retainedIds = new Set(entries.map(entry => entry.job.id));
        expandedQuietIds = expandedQuietIds.filter(id => retainedIds.has(id));
        const rows = History.project(entries, collapseRoutine && !runId, expandedQuietIds, selectedId);
        foldedCount = rows.reduce((count, row) => count + (row.quietGroup && !row.quietGroup.expanded ? row.quietGroup.ids.length : 0), 0);
        resultsAboutToChange(preserve !== false);
        const overview = provider.makeResult({id: "_now", title: qsTr("Now"), subtitle: qsTr("Local Git · AI tools · Applications · System"),
            score: 1, icon: "dashboard", primaryActionId: "inspect", metadata: {overview: true},
            actions: [{id: "inspect", label: qsTr("Review current status"), closePolicy: "keep-open", presentation: {group: "primary"}}]});
        replaceProviderResults([overview].concat(rows.map(function(row, index) {
            if (row.quietGroup) {
                const group = row.quietGroup;
                return provider.makeResult({id: group.id, title: qsTr("%1 no-change checks").arg(group.ids.length), score: -index,
                    subtitle: Presentation.label(group.first.lane) + " · " + (group.expanded ? qsTr("Expanded") : qsTr("Collapsed · loaded runs only")),
                    icon: group.expanded ? "expand_less" : "expand_more", primaryActionId: "toggle-quiet", metadata: {quietGroup: group},
                    actions: [{id: "toggle-quiet", label: group.expanded ? qsTr("Collapse checks") : qsTr("Expand checks"), icon: "unfold_more", accessKey: "E", closePolicy: "keep-open", presentation: {group: "primary"}}]});
            }
            const entry = row.run;
            // The shared store uses score even for provider-ranked results.
            // Preserve the catalog's chronology, not alphabetical title order.
            return provider.makeResult({id: entry.job.id, title: entry.title, score: -index,
                subtitle: Presentation.rowSubtitle(entry, controller.nowMs),
                icon: Presentation.outcomeIcon(entry.outcome),
                primaryActionId: "inspect", metadata: {run: entry},
                actions: [{id: "inspect", label: qsTr("Review run"), closePolicy: "keep-open", presentation: {group: "primary"}},
                    {id: "logs", label: qsTr("Read run log"), icon: "find_in_page", accessKey: "V", closePolicy: "keep-open", presentation: {group: "toolbar"}},
                    {id: "copy", label: qsTr("Copy run summary"), icon: "content_copy", accessKey: "C", closePolicy: "keep-open", presentation: {group: "toolbar"}},
                    {id: "copy-json", label: qsTr("Copy run JSON"), icon: "article", closePolicy: "keep-open", presentation: {group: "overflow"}},
                    {id: "copy-log", label: qsTr("Copy run log"), icon: "content_copy", closePolicy: "keep-open", presentation: {group: "overflow"}},
                    {id: "all", label: qsTr("Show all recent updates"), icon: "history", closePolicy: "keep-open", presentation: {group: "toolbar"}}]});
        })), false);
        if (selectedId && !filteredResults.some(result => result.id === selectedId)) {
            if (!settingsOpen) detailsOpen = false;
            selectFirst();
        }
        resultsChanged();
    }
    function toggleQuietGroup(): bool {
        if (!selectedQuietGroup) return false;
        const group = selectedQuietGroup;
        expandedQuietIds = expandedQuietIds.filter(id => !group.ids.includes(id));
        if (!group.expanded) expandedQuietIds = expandedQuietIds.concat(group.id.slice(7));
        publishResults();
        return true;
    }
    function runLogVersion(run: var): string {
        return JSON.stringify([run.outcome, run.job.status, run.job.phase, run.job.finished_at, run.job.exit_code, run.job.error]);
    }
    function cacheLog(text: string, error: string, truncated: bool): void {
        logCache = logCache.filter(log => log.id !== logRun).slice(-7).concat([{id: logRun, version: logVersion, text: text, error: error, truncated: truncated}]);
    }
    function readLog(run: var): bool {
        if (!uiActive || !run || logRequest) return false;
        logRun = run.job.id;
        logVersion = runLogVersion(run);
        logCache = logCache.filter(log => log.id !== logRun);
        logRequest = backend.nextRequestId("update-log");
        const sent = backend.call(logRequest, "updates.readLog", {run_id: logRun});
        if (!sent && logRequest) { logRequest = ""; cacheLog("", qsTr("Update log unavailable"), false); }
        return sent;
    }
    function autoReadLog(): void {
        if (!uiActive || !detailsOpen || settingsOpen || navigationBlocked || logRequest || !selectedRun || selectedLogRecord) return;
        if (["failed", "partial"].includes(selectedRun.outcome)) readLog(selectedRun);
    }
    function copyComponent(id: string, index: int): bool {
        if (!uiActive || navigationBlocked || !selectedRun || selectedRun.job.id !== id || index < 0 || index >= selectedRun.components.length) return false;
        return copyText(Presentation.componentSummary(selectedRun.components[index]), qsTr("Component versions copied"));
    }
    function copyText(text: string, message: string): bool {
        if (!uiActive || navigationBlocked) return false;
        copyError = "";
        return clipboardPublisher.publishText(text, message);
    }
    function timeLabel(seconds: var): string {
        return Presentation.timeLabel(seconds, nowMs);
    }
    function primarySelected(): bool { return selectedQuietGroup ? perform("toggle-quiet") : executeSelected("inspect"); }
    function triggerDetailAction(actionId: string): bool { return perform(actionId); }
    function perform(actionId: string): bool {
        if (!uiActive || navigationBlocked) return false;
        if (actionId === "all") { runId = ""; missingRun = false; laneFilter = ""; outcomeFilter = ""; filterText = ""; refresh(); return true; }
        if (actionId === "toggle-quiet") return toggleQuietGroup();
        if (actionId === "inspect" && hasSelection) { openDetails(); return true; }
        if (!selectedRun) return false;
        if (actionId === "logs") { selectDetailsTab("log"); return logRequest ? false : readLog(selectedRun); }
        if (actionId === "copy") return copyText(Presentation.runSummary(selectedRun, nowMs), qsTr("Run summary copied"));
        if (actionId === "copy-json") return copyText(JSON.stringify(selectedRun, null, 2), qsTr("Run JSON copied"));
        if (actionId === "copy-log" && selectedLogRecord && !selectedLogError && selectedLog && !selectedLogLoading)
            return copyText(selectedLog, qsTr("Run log copied"));
        return false;
    }
    Io.ClipboardPublisher {
        id: clipboardPublisher
        onFinished: function(succeeded, message) { controller.copyError = succeeded ? "" : message; }
    }
    Io.BarDaemonBackend {
        id: backend
        daemonName: "bar-daemon"
        expectedProtocol: Contract.protocol
        expectedVersion: Contract.version
        streams: ["updates.changed"]
        active: controller.uiActive || requestRunning
        validateRequest: Contract.requestError
        validateEvent: Contract.eventError
        onTransportReady: controller.refresh()
        onResponseReceived: function(id, envelope, transportError) { controller.finish(id, envelope, transportError); }
        onSendFailed: function(id, message) { controller.finish(id, null, message); }
        onTransportFailed: function(message, ids) {
            if (controller.logRequest) controller.cacheLog("", message, false);
            if (controller.ownedRequest) controller.errorText = message;
            if (controller.overviewRequest) controller.overviewError = message;
            controller.overviewRequest = "";
            controller.overviewLoading = false;
            controller.overviewRefreshPending = false;
            controller.retireHistory();
            controller.logRequest = "";
        }
        onEventReceived: function(event) { if (event.event === "changed") controller.scheduleRefresh(); }
    }
}
