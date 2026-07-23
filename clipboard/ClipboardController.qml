import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

Item {
    id: controller

    property bool uiActive: false
    property string currentWorkspaceId: ""
    property string status: "Loading clipboard history…"
    property string sessionId: ""
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    readonly property var filteredResults: results.visibleResults
    readonly property var filteredResultsModel: results.visibleModel
    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) { return key.indexOf("query-") === 0; })
    readonly property int closedWindowWidth: Ui.Theme.popupClosedWidth
    readonly property int surfaceWindowWidth: closedWindowWidth
    readonly property int currentWindowWidth: closedWindowWidth
    readonly property int contentVerticalMargin: Ui.Theme.contentVerticalMargin

    signal focusSearchRequested

    function activateUi(workspaceId) {
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
        backend.beginSession();
        refresh();
    }
    function deactivateUi() { uiActive = false; }
    function refresh() {
        status = "Loading clipboard history…";
        results.beginQuery(filterText, {}, [provider.providerId], 100);
    }
    function requestHistory(id, text, generation, limit) { backend.query(id, text, generation, limit); }
    function cancelQuery(requestId) { backend.cancelRequest(requestId); }
    function applyHistory(id, history) {
        const batch = {
            providerId: provider.providerId,
            queryId: id,
            replace: true,
            complete: true,
            results: provider.resultsForEntries(history.entries || [])
        };
        results.applyBatch(batch);
        status = history.entries.length + " clipboard entries" + (history.has_more ? " · more available" : "");
    }
    function applySession(session) { sessionId = session.id || ""; }
    function handleFailure(id, message) {
        if (id === results.activeQueryId)
            results.clear();
        status = message;
    }
    function handleTransportFailure(message) { status = message; }
    function moveSelection(delta) { results.move(delta); }

    Timer {
        id: searchTimer
        interval: 120
        repeat: false
        onTriggered: if (controller.uiActive) controller.refresh()
    }
    onFilterTextChanged: if (uiActive) searchTimer.restart()

    Core.ProviderRegistry {
        id: providers
        ClipboardProvider { id: provider; controller: controller }
    }
    Core.ResultStore { id: results; registry: providers }
    ClipboardBackend { id: backend; controller: controller }
}
