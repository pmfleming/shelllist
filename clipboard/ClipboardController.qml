import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

Item {
    id: controller

    property bool uiActive: false
    property string currentWorkspaceId: ""
    property string status: "Loading clipboard history…"
    property string sessionId: ""
    property bool detailsOpen: false
    property bool detailsLoading: false
    property string detailsError: ""
    property var details: null
    property var thumbnail: null
    property var currentEntry: null
    property int detailSequence: 0
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    readonly property var filteredResults: results.visibleResults
    readonly property var filteredResultsModel: results.visibleModel
    readonly property var selectedResult: results.selected()
    readonly property var selectedEntry: selectedResult ? selectedResult.payload : null
    readonly property bool hasSelection: !!selectedResult
    readonly property bool refreshInFlight: Object.keys(backend.pending).some(function (key) { return key.indexOf("query-") === 0; })
    readonly property int closedWindowWidth: Ui.Theme.popupClosedWidth
    readonly property int openWindowWidth: Ui.Theme.popupOpenWidth
    readonly property int surfaceWindowWidth: openWindowWidth
    readonly property int contentMargin: Ui.Theme.contentMargin
    readonly property int contentVerticalMargin: Ui.Theme.contentVerticalMargin
    readonly property int listPaneWidth: closedWindowWidth - 2 * contentMargin
    readonly property int detailsGapWidth: Ui.Theme.detailsGapWidth
    readonly property real detailsRenderCutoff: 0.025
    property real detailsExpansionProgress: detailsOpen ? 1 : 0
    readonly property real detailsPaintProgress: (!detailsOpen && detailsExpansionProgress <= detailsRenderCutoff) ? 0 : detailsExpansionProgress
    readonly property real detailsPaneFullWidth: openWindowWidth - closedWindowWidth - detailsGapWidth
    readonly property real detailsPaneWidth: detailsPaintProgress * detailsPaneFullWidth
    readonly property real detailsPaneGapWidth: detailsPaintProgress * detailsGapWidth
    readonly property bool detailsRendered: detailsOpen || detailsExpansionProgress > detailsRenderCutoff
    readonly property int currentWindowWidth: Math.round(closedWindowWidth + detailsPaintProgress * (openWindowWidth - closedWindowWidth))

    signal focusSearchRequested
    signal focusListTopRequested

    function activateUi(workspaceId) {
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
        backend.beginSession();
        refresh();
    }
    function deactivateUi() {
        uiActive = false;
        detailsOpen = false;
        clearDetails();
    }
    function refresh() {
        status = "Loading clipboard history…";
        results.beginQuery(filterText, {}, [provider.providerId], 100);
    }
    function scheduleRefresh() { refreshTimer.restart(); }
    function requestHistory(id, text, generation, limit) { backend.query(id, text, generation, limit); }
    function cancelQuery(requestId) { backend.cancelRequest(requestId); }
    function applyHistory(id, history) {
        results.applyBatch({
            providerId: provider.providerId,
            queryId: id,
            replace: true,
            complete: true,
            results: provider.resultsForEntries(history.entries || [])
        });
        currentEntry = history.current || null;
        status = history.entries.length + " clipboard entries" + (history.has_more ? " · more available" : "");
        if (detailsOpen)
            loadDetails();
    }
    function applySession(session) { sessionId = session.id || ""; }
    function openDetails() {
        if (!hasSelection)
            return;
        detailsOpen = true;
        loadDetails();
    }
    function closeDetails() { detailsOpen = false; }
    function toggleDetails() { detailsOpen ? closeDetails() : openDetails(); }
    function clearDetails() {
        details = null;
        thumbnail = null;
        detailsError = "";
        detailsLoading = false;
    }
    function loadDetails() {
        clearDetails();
        if (!selectedEntry)
            return;
        detailsLoading = true;
        detailSequence += 1;
        const suffix = "-" + detailSequence;
        backend.details("details" + suffix, selectedEntry);
        if (selectedEntry.kind === "image")
            backend.thumbnail("thumbnail" + suffix, selectedEntry);
    }
    function applyDetails(id, value) {
        if (id.indexOf("details-") !== 0 || !selectedEntry || value.entry.id !== selectedEntry.id)
            return;
        details = value;
        detailsLoading = false;
        detailsError = "";
    }
    function applyThumbnail(id, value) {
        if (id.indexOf("thumbnail-") !== 0 || !selectedEntry || value.entry_id !== selectedEntry.id)
            return;
        thumbnail = value;
    }
    function handleFailure(id, message) {
        if (id === results.activeQueryId) {
            results.clear();
            status = message;
        } else if (id.indexOf("details-") === 0 || id.indexOf("thumbnail-") === 0) {
            detailsLoading = false;
            detailsError = message;
        } else {
            status = message;
        }
    }
    function handleTransportFailure(message) {
        results.clear();
        clearDetails();
        status = message;
    }
    function moveSelection(delta) { results.move(delta); }

    Timer { id: searchTimer; interval: 120; repeat: false; onTriggered: if (controller.uiActive) controller.refresh() }
    Timer { id: refreshTimer; interval: 90; repeat: false; onTriggered: if (controller.uiActive) controller.refresh() }

    onFilterTextChanged: if (uiActive) searchTimer.restart()
    onSelectedResultChanged: if (detailsOpen) loadDetails()
    Behavior on detailsExpansionProgress {
        enabled: !Ui.Theme.noAnimations
        NumberAnimation { duration: Ui.Theme.animationNormal; easing.type: Ui.Theme.easingGentle }
    }

    Core.ProviderRegistry {
        id: providers
        ClipboardProvider { id: provider; controller: controller }
    }
    Core.ResultStore { id: results; registry: providers }
    ClipboardBackend { id: backend; controller: controller }
}
