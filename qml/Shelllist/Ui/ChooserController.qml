import QtQuick

Item {
    id: root
    property bool uiActive: false
    property string currentWorkspaceId: ""
    property bool detailsOpen: false
    property bool hasSelection: false
    property var selectionModel: null
    property var detailActions: []
    property bool navigationBlocked: false
    property bool actionInFlight: false
    property bool navigationPrimaryEnabled: true
    property bool navigationCloseEnabled: true
    property bool navigationHelpOpen: false
    property real detailsExpansionProgress: detailsOpen ? 1 : 0
    property real availableScreenWidth: 0
    property real closedWidthFraction: 0
    property real openWidthFraction: 0
    property int minimumClosedWindowWidth: Theme.popupClosedWidth
    property int maximumClosedWindowWidth: Theme.popupClosedWidth
    property int minimumOpenWindowWidth: Theme.popupOpenWidth
    property int maximumOpenWindowWidth: Theme.popupOpenWidth
    property real surfaceHeightRatio: Theme.popupHeightRatio
    property int surfaceTopInset: 0
    property int surfaceBottomInset: 0
    property string surfaceAlignment: "center"
    readonly property alias navigation: navigationModel

    readonly property int closedWindowWidth: closedWidthFraction > 0 && availableScreenWidth > 0
        ? Math.round(Math.max(minimumClosedWindowWidth, Math.min(maximumClosedWindowWidth,
            availableScreenWidth * closedWidthFraction))) : Theme.popupClosedWidth
    readonly property int openWindowWidth: openWidthFraction > 0 && availableScreenWidth > 0
        ? Math.round(Math.max(minimumOpenWindowWidth, Math.min(maximumOpenWindowWidth,
            availableScreenWidth * openWidthFraction))) : Theme.popupOpenWidth
    readonly property int surfaceWindowWidth: openWindowWidth
    readonly property int contentMargin: Theme.contentMargin
    readonly property int contentVerticalMargin: Theme.contentVerticalMargin
    readonly property int listPaneWidth: closedWindowWidth - 2 * contentMargin
    readonly property int detailsGapWidth: Theme.detailsGapWidth
    readonly property real detailsRenderCutoff: 0.025
    readonly property real detailsPaintProgress: !detailsOpen && detailsExpansionProgress <= detailsRenderCutoff
        ? 0 : detailsExpansionProgress
    readonly property real detailsPaneFullWidth: openWindowWidth - closedWindowWidth - detailsGapWidth
    readonly property real detailsPaneWidth: detailsPaintProgress * detailsPaneFullWidth
    readonly property real detailsPaneGapWidth: detailsPaintProgress * detailsGapWidth
    readonly property bool detailsRendered: detailsOpen || detailsExpansionProgress > detailsRenderCutoff
    readonly property int currentWindowWidth: Math.round(closedWindowWidth
        + detailsPaintProgress * (openWindowWidth - closedWindowWidth))

    signal closeWindowRequested
    signal focusSearchRequested
    signal focusListTopRequested
    signal screenshotRequested

    function activateUi(workspaceId) { activateUiState(workspaceId); }
    function deactivateUi() { deactivateUiState(); }
    function refresh() {}
    function setPower() {}
    function captureScreenshot(x, y, width, height) { return false; }

    function activateUiState(workspaceId) {
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
    }

    function deactivateUiState() {
        uiActive = false;
        navigationHelpOpen = false;
    }

    function openNavigationHelp() { navigationHelpOpen = true; }
    function closeNavigationHelp() { navigationHelpOpen = false; }
    function toggleNavigationHelp() { navigationHelpOpen ? closeNavigationHelp() : openNavigationHelp(); }
    function dismissNavigationHelp(): bool {
        if (!navigationHelpOpen)
            return false;
        closeNavigationHelp();
        return true;
    }
    function dismissDetailsOrWindow(): bool {
        if (detailsOpen)
            closeDetails();
        else
            closeWindowRequested();
        return true;
    }
    function dismissNavigation(): bool {
        return dismissNavigationHelp() || dismissDetailsOrWindow();
    }

    function moveSelection(delta) { if (selectionModel) selectionModel.move(delta); }
    function selectionAtStart() { return !selectionModel || selectionModel.selectedIndex <= 0; }
    function selectFirst() { if (selectionModel) selectionModel.selectFirst(); }
    function select(index) { if (selectionModel) selectionModel.selectedIndex = index; }
    function openDetails() { if (hasSelection) detailsOpen = true; }
    function closeDetails() { detailsOpen = false; }
    function toggleDetails() { detailsOpen ? closeDetails() : openDetails(); }
    function primarySelected() { return false; }
    function triggerDetailAction(actionId) { return false; }

    ResultNavigation {
        id: navigationModel
        controller: root
        blocked: root.navigationBlocked
        primaryEnabled: root.navigationPrimaryEnabled
        closeEnabled: root.navigationCloseEnabled
    }

    Behavior on detailsExpansionProgress {
        enabled: !Theme.noAnimations
        NumberAnimation {
            duration: Theme.animationInteractive
            easing.type: Theme.easingResponsive
        }
    }
}
