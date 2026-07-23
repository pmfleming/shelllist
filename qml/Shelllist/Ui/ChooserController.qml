import QtQuick

Item {
    property bool uiActive: false
    property string currentWorkspaceId: ""
    property bool detailsOpen: false
    property bool hasSelection: false
    property var selectionModel: null
    property var detailActions: []
    property real detailsExpansionProgress: detailsOpen ? 1 : 0

    readonly property int closedWindowWidth: Theme.popupClosedWidth
    readonly property int openWindowWidth: Theme.popupOpenWidth
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

    function activateUiState(workspaceId) {
        uiActive = true;
        currentWorkspaceId = workspaceId || "";
    }

    function deactivateUiState() {
        uiActive = false;
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

    Behavior on detailsExpansionProgress {
        enabled: !Theme.noAnimations
        NumberAnimation { duration: Theme.animationNormal; easing.type: Theme.easingGentle }
    }
}
