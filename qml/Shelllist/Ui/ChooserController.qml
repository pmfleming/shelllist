import QtQuick

Item {
    id: root
    property bool uiActive: false
    property ChooserMemory viewMemory: null
    property var focusMemory: ({})
    property bool uiSuspending: false
    property int uiGeneration: 0
    onUiActiveChanged: {
        uiGeneration++;
        if (uiActive)
            uiSuspending = false;
    }
    property string currentWorkspaceId: ""
    property bool detailsOpen: false
    property bool hasSelection: false
    property var selectionModel: null
    property var detailActions: []
    property bool navigationBlocked: false
    property bool actionInFlight: false
    property bool navigationPrimaryEnabled: true
    property bool navigationCloseEnabled: true
    property real detailsExpansionProgress: detailsOpen ? 1 : 0
    property real availableScreenWidth: 0
    property real availableScreenHeight: 0
    property bool expandable: true
    readonly property PopoverGeometry geometry: PopoverGeometry {
        availableWidth: root.availableScreenWidth > 0 ? root.availableScreenWidth : 1280
        availableHeight: root.availableScreenHeight > 0 ? root.availableScreenHeight : 960
        expandable: root.expandable
    }
    property double lastSearchRankLatencyMs: -1
    property double lastCatalogToModelLatencyMs: -1
    readonly property alias navigation: navigationModel

    readonly property int closedWindowWidth: geometry.closedWidth
    readonly property int openWindowWidth: geometry.openWidth
    readonly property int contentMargin: geometry.contentMargin
    readonly property int contentVerticalMargin: Theme.contentVerticalMargin
    readonly property int listPaneWidth: closedWindowWidth - 2 * contentMargin
    readonly property int detailsGapWidth: geometry.detailsGap
    readonly property real detailsRenderCutoff: 0.025
    readonly property real detailsPaintProgress: !detailsOpen && detailsExpansionProgress <= detailsRenderCutoff ? 0 : detailsExpansionProgress
    readonly property real detailsPaneFullWidth: openWindowWidth - closedWindowWidth - detailsGapWidth
    readonly property real detailsPaneWidth: detailsPaintProgress * detailsPaneFullWidth
    readonly property real detailsPaneGapWidth: detailsPaintProgress * detailsGapWidth
    readonly property bool detailsRendered: detailsOpen || detailsExpansionProgress > detailsRenderCutoff
    readonly property int currentWindowWidth: Math.round(closedWindowWidth + detailsPaintProgress * (openWindowWidth - closedWindowWidth))

    signal resultsAboutToChange(bool preserveViewport)
    signal resultsChanged
    signal detailsClosing
    signal navigationInteracted
    signal uiSuspensionRequested
    signal restoreSessionFocusRequested
    signal closeWindowRequested
    signal focusSearchRequested
    signal focusListTopRequested
    signal focusDetailsRequested
    signal searchTextRequested(string text)
    signal screenshotRequested

    function activateUi(workspaceId) {
        activateUiState(workspaceId);
    }
    function deactivateUi() {
        deactivateUiState();
    }
    function refresh() {
    }
    function cycleDetailsTab(backwards: bool) {
    }
    function tabAfter(tabs: var, current: string, backwards: bool): string {
        const index = tabs.indexOf(current);
        if (index < 0)
            return tabs[backwards ? tabs.length - 1 : 0] || "";
        return tabs[(index + (backwards ? -1 : 1) + tabs.length) % tabs.length] || "";
    }
    function setPower() {
    }
    function setDetailsTab(tab: string): void {
    }
    function captureScreenshot(x, y, width, height) {
        return false;
    }

    function restoreUiFocus(): void {
        if (!uiActive || uiSuspending)
            return;
        if (viewMemory)
            restoreSessionFocusRequested();
        else
            focusSearchRequested();
    }
    function prepareUiDeactivation(): void {
        if (!uiActive || uiSuspending)
            return;
        if (viewMemory)
            viewMemory.synchronize();
        uiSuspending = true;
        uiSuspensionRequested();
    }
    function resultKeyAt(index: int): string { return ""; }
    function resultIndexForKey(key: string): int { return -1; }

    function activateUiState(workspaceId) {
        uiSuspending = false;
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
    }

    function deactivateUiState() {
        prepareUiDeactivation();
        uiActive = false;
    }
    function dismissDetailsOrWindow(): bool {
        if (viewMemory)
            viewMemory.synchronize();
        if (detailsOpen)
            closeDetails();
        else
            closeWindowRequested();
        return true;
    }
    function dismissNavigation(): bool {
        return dismissDetailsOrWindow();
    }

    function moveSelection(delta) {
        if (selectionModel)
            selectionModel.move(delta);
    }
    function selectionAtStart() {
        return !selectionModel || selectionModel.selectedIndex <= 0;
    }
    function selectFirst() {
        if (selectionModel)
            selectionModel.selectFirst();
    }
    function select(index) {
        if (selectionModel)
            selectionModel.selectedIndex = index;
    }
    function openDetails() {
        if (viewMemory)
            viewMemory.synchronize();
        if (hasSelection)
            detailsOpen = true;
    }
    function closeDetails() {
        detailsClosing();
        if (viewMemory)
            viewMemory.synchronize();
        detailsOpen = false;
    }
    function toggleDetails() {
        if (viewMemory)
            viewMemory.synchronize();
        detailsOpen ? closeDetails() : openDetails();
    }
    function primarySelected() {
        return false;
    }
    function triggerDetailAction(actionId) {
        return false;
    }

    ResultNavigation {
        id: navigationModel
        controller: root
        blocked: root.navigationBlocked
        primaryEnabled: root.navigationPrimaryEnabled
        closeEnabled: root.navigationCloseEnabled
    }

    InteractiveBehavior on detailsExpansionProgress {}
}
