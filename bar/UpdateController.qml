import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "BarProtocol.generated.js" as Contract

Ui.ProviderChooserController {
    id: controller
    property BarController barController: null
    property string errorText: ""
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
    property string logText: ""
    readonly property string selectedLog: selectedRun && selectedRun.job.id === logRun ? logText : ""
    property alias backend: backend
    readonly property var selectedRun: selectedResult ? selectedResult.metadata.run : null
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
        refresh();
    }
    onUiActiveChanged: if (!uiActive) { ownedRequest = ""; logRequest = ""; loading = false; }
    onFilterTextChanged: { runId = ""; ownedRequest = ""; loading = false; }
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
            const failure = backend.responseError(envelope, transportError, qsTr("Worker journal unavailable"));
            if (failure) { errorText = failure; return; }
            const log = envelope.data ? envelope.data.log : null;
            if (!log || log.run_id !== logRun || typeof log.text !== "string") { errorText = qsTr("Invalid journal reply"); return; }
            logText = log.text || qsTr("No readable journal entries for this worker. Child-build output may be recorded separately.");
            if (log.truncated) logText += "\n" + qsTr("Output truncated to 32 KiB.");
            return;
        }
        if (id !== ownedRequest) return;
        ownedRequest = "";
        loading = false;
        errorText = backend.responseError(envelope, transportError, qsTr("Update history unavailable"));
        if (errorText) return;
        const page = envelope.data ? envelope.data.history : null;
        if (!page || !Array.isArray(page.entries) || page.entries.length > 100 || typeof page.available !== "boolean" || typeof page.revision !== "string"
                || !(page.cursor === null || typeof page.cursor === "string")
                || page.entries.some(entry => !validEntry(entry))) {
            errorText = qsTr("Invalid update history reply"); return;
        }
        if (!page.available || (page.error && entries.length > 0)) {
            available = page.available;
            cursor = "";
            errorText = (page.error || qsTr("Update history has not been published"))
                + (entries.length > 0 ? " · " + qsTr("Showing cached runs") : "");
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
        entries = next;
        available = page.available;
        cursor = page.cursor || "";
        coverage = page.coverage || "";
        errorText = page.error || (missingRun ? qsTr("The requested run is no longer retained. Showing recent updates.") : "");
        replaceProviderResults(entries.map(function(entry) {
            return provider.makeResult({id: entry.job.id, title: entry.title,
                subtitle: entry.lane + " · " + controller.timeLabel(entry.job.finished_at || entry.job.started_at),
                icon: ["failed", "partial", "blocked", "interrupted"].includes(entry.outcome) ? "warning" : "history",
                primaryActionId: "inspect", metadata: {run: entry},
                actions: [{id: "inspect", label: qsTr("Review run"), closePolicy: "keep-open", presentation: {group: "primary"}},
                    {id: "logs", label: qsTr("Read worker journal"), accessKey: "V", closePolicy: "keep-open", presentation: {group: "toolbar"}},
                    {id: "copy", label: qsTr("Copy run summary"), accessKey: "C", closePolicy: "keep-open", presentation: {group: "toolbar"}},
                    {id: "all", label: qsTr("Show all recent updates"), accessKey: "A", closePolicy: "keep-open", presentation: {group: "toolbar"}}]});
        }), false);
        if (runId && entries.length) { selectedIndex = 0; openDetails(); }
    }
    function timeLabel(seconds: var): string {
        return Number.isFinite(Number(seconds)) && Number(seconds) > 0 ? Qt.formatDateTime(new Date(Number(seconds) * 1000), "yyyy-MM-dd HH:mm:ss") : qsTr("Not recorded");
    }
    function primarySelected(): bool { return executeSelected("inspect"); }
    function triggerDetailAction(actionId: string): bool { return perform(actionId); }
    function perform(actionId: string): bool {
        if (!uiActive || navigationBlocked) return false;
        if (actionId === "all") { runId = ""; missingRun = false; filterText = ""; refresh(); return true; }
        if (!selectedRun) return false;
        if (actionId === "inspect") { openDetails(); return true; }
        if (actionId === "logs") {
            if (logRequest) return false;
            logRun = selectedRun.job.id;
            logText = "";
            logRequest = backend.nextRequestId("update-log");
            return backend.call(logRequest, "updates.readLog", {run_id: logRun});
        }
        if (actionId === "copy") return clipboardPublisher.publishText(JSON.stringify(selectedRun, null, 2), qsTr("Run summary copied"));
        return false;
    }
    Io.ClipboardPublisher {
        id: clipboardPublisher
        onFinished: function(succeeded, message) { if (!succeeded) controller.errorText = message; }
    }
    Io.BarDaemonBackend {
        id: backend
        daemonName: "bar-daemon"
        expectedProtocol: "bar-api"
        expectedVersion: 1
        streams: ["updates.changed"]
        active: controller.uiActive || requestRunning
        validateRequest: Contract.requestError
        validateEvent: Contract.eventError
        onTransportReady: controller.refresh()
        onResponseReceived: function(id, envelope, transportError) { controller.finish(id, envelope, transportError); }
        onSendFailed: function(id, message) { controller.finish(id, null, message); }
        onTransportFailed: function(message, ids) { controller.ownedRequest = ""; controller.logRequest = ""; controller.loading = false; controller.errorText = message; }
        onEventReceived: function(event) { if (event.event === "changed") controller.scheduleRefresh(); }
    }
}
