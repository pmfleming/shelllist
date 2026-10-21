import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "BarProtocol.generated.js" as Contract
import "UpdatePresentation.js" as Presentation

Ui.ProviderChooserController {
    id: controller
    property BarController barController: null
    property string errorText: ""
    property string copyError: ""
    property string warningText: ""
    property string warningBrief: ""
    property int total: 0
    property double nowMs: Date.now()
    readonly property string countLabel: filterText.trim() ? qsTr("%1 of %2 matching runs · read only").arg(entries.length).arg(total)
        : qsTr("%1 of %2 runs · read only").arg(entries.length).arg(total)
    property string coverage: ""
    property bool available: false
    property bool loading: false
    property string cursor: ""
    property string runId: ""
    property bool missingRun: false
    property var entries: []
    property string ownedRequest: ""
    property bool appendRequest: false
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
        key: controller.selectedResult ? controller.selectedResult.key : ""
        tab: "details"
        initialTab: "details"
        tabs: ["details"]
        onRestoreRequested: function(open, tab) { controller.detailsOpen = open; }
    }
    function activateUi(workspaceId: string): void {
        activateUiState(workspaceId);
        nowMs = Date.now();
        publishResults();
        refresh();
    }
    onUiActiveChanged: if (!uiActive) { ownedRequest = ""; logRequest = ""; loading = false; logCache = []; }
    onSelectedRunChanged: Qt.callLater(autoReadLog)
    onDetailsOpenChanged: Qt.callLater(autoReadLog)
    onLogRequestChanged: Qt.callLater(autoReadLog)
    onNavigationBlockedChanged: if (!navigationBlocked) Qt.callLater(autoReadLog)
    onFilterTextChanged: { runId = ""; ownedRequest = ""; loading = false; }
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
    function refresh(): void { requestPage(false); }
    function loadMore(): void { if (cursor && !loading) requestPage(true); }
    function requestPage(append: bool): void {
        if (!uiActive || !backend.ready) return;
        ownedRequest = backend.nextRequestId("update-history");
        appendRequest = append;
        loading = true;
        errorText = "";
        if (!backend.call(ownedRequest, "updates.queryHistory", {query: filterText, cursor: append ? cursor : null, run_id: runId || null, limit: 50})) {
            loading = false;
        }
    }
    function validEntry(entry: var): bool {
        const optionalText = value => value === null || typeof value === "string";
        const time = value => typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
        return !!entry && entry.schema_version === 1 && typeof entry.lane === "string" && !!entry.job
            && /^[A-Za-z0-9][A-Za-z0-9-]{0,159}$/.test(entry.job.id || "")
            && [entry.title, entry.outcome, entry.job.operation, entry.job.phase, entry.job.status].every(value => typeof value === "string")
            && time(entry.job.started_at) && (entry.job.finished_at === null || time(entry.job.finished_at))
            && (entry.job.exit_code === null || Number.isSafeInteger(entry.job.exit_code))
            && optionalText(entry.job.error) && Array.isArray(entry.components) && entry.components.length <= 32
            && entry.components.every(part => !!part && typeof part.name === "string" && typeof part.phase === "string"
                && typeof part.changed === "boolean" && optionalText(part.before) && optionalText(part.after) && optionalText(part.error));
    }
    function finish(id: string, envelope: var, transportError: string): void {
        if (!uiActive) return;
        if (id === logRequest && logRequest) {
            logRequest = "";
            const failure = backend.responseError(envelope, transportError, qsTr("Update log unavailable"));
            if (failure) { cacheLog("", failure, false); return; }
            const log = envelope.data ? envelope.data.log : null;
            if (!log || log.run_id !== logRun || typeof log.text !== "string" || log.text.length > 32768 || typeof log.truncated !== "boolean") {
                cacheLog("", qsTr("Invalid update log reply"), false); return;
            }
            cacheLog(log.text, "", log.truncated);
            return;
        }
        if (!ownedRequest || id !== ownedRequest) return;
        ownedRequest = "";
        loading = false;
        errorText = backend.responseError(envelope, transportError, qsTr("Update history unavailable"));
        if (errorText) return;
        const page = envelope.data ? envelope.data.history : null;
        if (!page || !Array.isArray(page.entries) || page.entries.length > 100 || typeof page.available !== "boolean" || typeof page.revision !== "string"
                || !(page.cursor === null || typeof page.cursor === "string")
                || !Number.isSafeInteger(page.total) || page.total < page.entries.length
                || !(page.error === null || typeof page.error === "string") || typeof page.coverage !== "string"
                || page.entries.some(entry => !validEntry(entry))) {
            errorText = qsTr("Invalid update history reply"); return;
        }
        if (!page.available) {
            available = page.available;
            cursor = "";
            errorText = (page.error || qsTr("Update history has not been published"))
                + (entries.length > 0 ? " · " + qsTr("Showing cached runs") : "");
            return;
        }
        if (runId && !page.entries.length && page.error) {
            warningText = page.error;
            warningBrief = qsTr("Requested run could not be read");
            return;
        }
        if (runId && !page.entries.length && page.available && !page.error) {
            runId = "";
            missingRun = true;
            refresh();
            return;
        }
        if (runId && (page.entries.length !== 1 || page.entries[0].job.id !== runId)) {
            errorText = qsTr("Update history reply targets another run"); return;
        }
        const next = appendRequest ? entries.concat(page.entries) : page.entries;
        if (new Set(next.map(entry => entry.job.id)).size !== next.length) {
            errorText = qsTr("Duplicate update history identities"); return;
        }
        if (page.total < next.length) { errorText = qsTr("Invalid update history total"); return; }
        entries = next;
        total = page.total;
        available = page.available;
        cursor = page.cursor || "";
        coverage = page.coverage;
        // The wire diagnostics are capped and may contain multi-line/source errors,
        // so do not invent an unreadable-record count by splitting the string.
        warningText = page.error || (missingRun ? qsTr("The requested run is no longer retained. Showing recent updates.") : "");
        warningBrief = page.error ? qsTr("Some update history could not be read") : warningText;
        publishResults();
        if (runId && entries.length) { selectedIndex = filteredResults.findIndex(result => result.id === runId); openDetails(); }
    }
    function publishResults(): void {
        const overview = provider.makeResult({id: "_now", title: qsTr("Now"), subtitle: qsTr("Current worker status and deferred candidate"),
            score: 1, icon: "today", primaryActionId: "inspect", metadata: {overview: true},
            actions: [{id: "inspect", label: qsTr("Review current status"), closePolicy: "keep-open", presentation: {group: "primary"}}]});
        replaceProviderResults([overview].concat(entries.map(function(entry, index) {
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
                    {id: "all", label: qsTr("Show all recent updates"), icon: "history", accessKey: "A", closePolicy: "keep-open", presentation: {group: "toolbar"}}]});
        })), false);
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
        if (!uiActive || !detailsOpen || navigationBlocked || logRequest || !selectedRun || selectedLogRecord) return;
        if (["failed", "partial"].includes(selectedRun.outcome)) readLog(selectedRun);
    }
    function copyComponent(id: string, index: int): bool {
        if (!uiActive || navigationBlocked || !selectedRun || selectedRun.job.id !== id || index < 0 || index >= selectedRun.components.length) return false;
        return copyText(Presentation.componentSummary(selectedRun.components[index]), qsTr("Component versions copied"));
    }
    function copyText(text: string, message: string): bool {
        copyError = "";
        return clipboardPublisher.publishText(text, message);
    }
    function timeLabel(seconds: var): string {
        return Presentation.timeLabel(seconds, nowMs);
    }
    function primarySelected(): bool { return executeSelected("inspect"); }
    function triggerDetailAction(actionId: string): bool { return perform(actionId); }
    function perform(actionId: string): bool {
        if (!uiActive || navigationBlocked) return false;
        if (actionId === "all") { runId = ""; missingRun = false; filterText = ""; refresh(); return true; }
        if (actionId === "inspect" && hasSelection) { openDetails(); return true; }
        if (!selectedRun) return false;
        if (actionId === "logs") return readLog(selectedRun);
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
            controller.ownedRequest = "";
            controller.logRequest = "";
            controller.loading = false;
        }
        onEventReceived: function(event) { if (event.event === "changed") controller.scheduleRefresh(); }
    }
}
