import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io

ChooserController {
    id: controller

    required property Core.Provider provider
    property alias filterText: results.queryText
    property alias selectedIndex: results.selectedIndex
    property int filterRefreshDelay: 0
    property int scheduledRefreshDelay: 0
    property bool closeDetailsWithoutSelection: false
    property bool sharedScreenshotEnabled: false
    property bool sharedScreenshotBlocked: actionInFlight
    property string sharedScreenshotStartMessage: "Capturing window…"

    readonly property bool sharedScreenshotInFlight: sharedScreenshotCapture.inFlight
    readonly property var filteredResults: results.visibleResults
    readonly property var filteredResultsModel: results.visibleModel
    readonly property var selectedResult: results.selected()
    readonly property double lastSearchRankLatencyMs: results.lastSearchRankLatencyMs
    readonly property double lastCatalogToModelLatencyMs:
        results.lastCatalogToModelLatencyMs

    hasSelection: !!selectedResult
    selectionModel: results
    detailActions: providers.actionsFor(selectedResult)

    function beginProviderQuery(context: var, limit: int): var { return results.beginQuery(filterText, context || ({}), [provider.providerId], limit); }

    function applyProviderQuery(id: string, values: var): bool {
        return results.applyNormalizedBatch({
            providerId: provider.providerId,
            queryId: id,
            replace: true,
            complete: true,
            results: values || []
        });
    }

    function replaceProviderResults(values: var, resetSelection: bool): void {
        results.replaceNormalizedProviderResults(provider.providerId,
            values || [], resetSelection);
    }

    function clearProviderResults(): void { results.clear(); }
    function isActiveQuery(id: string): bool { return id === results.activeQueryId; }

    function executeSelected(actionId: string): bool {
        return !!selectedResult && providers.execute(selectedResult, actionId, { workspaceId: currentWorkspaceId });
    }

    function captureScreenshot(x: real, y: real, width: real, height: real): bool {
        return sharedScreenshotEnabled
            && sharedScreenshotCapture.captureRegion(x, y, width, height);
    }

    function scheduleRefresh(): void {
        if (scheduledRefreshDelay > 0)
            scheduledRefreshTimer.restart();
        else if (uiActive)
            refresh();
    }

    onFilterTextChanged: {
        if (uiActive && filterRefreshDelay > 0)
            filterRefreshTimer.restart();
    }
    onSelectedResultChanged: if (closeDetailsWithoutSelection && !hasSelection) detailsOpen = false

    Core.ProviderRegistry {
        id: providers
        providers: [controller.provider]
    }
    Core.ResultStore { id: results; registry: providers }

    Io.ClipboardScreenshotCapture {
        id: sharedScreenshotCapture
        active: controller.sharedScreenshotEnabled && controller.uiActive
        blocked: controller.sharedScreenshotBlocked
        startMessage: controller.sharedScreenshotStartMessage
        onStatusChanged: function (message) {
            controller.sharedScreenshotStatusChanged(message);
        }
    }

    signal sharedScreenshotStatusChanged(string message)

    Timer {
        id: filterRefreshTimer
        interval: controller.filterRefreshDelay
        repeat: false
        onTriggered: if (controller.uiActive) controller.refresh()
    }
    Timer {
        id: scheduledRefreshTimer
        interval: controller.scheduledRefreshDelay
        repeat: false
        onTriggered: if (controller.uiActive) controller.refresh()
    }
}
