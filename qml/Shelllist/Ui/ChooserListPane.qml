pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: pane

    required property ChooserController chooserController
    required property Component rowDelegate
    property real densityScale: Theme.densityScale(height + 2 * chooserController.contentVerticalMargin, chooserController.contentVerticalMargin)
    property Component listOptionsComponent: null
    // Expose the owning controls directly instead of maintaining forwarding state.
    property alias listFooterComponent: body.listFooterComponent
    property alias preserveViewportOnAppend: body.preserveViewportOnAppend
    readonly property bool listNearEnd: body.listNearEnd
    property alias resultModel: body.resultModel
    property alias emptyText: body.emptyText
    property alias emptyIcon: body.emptyIcon
    property alias emptyState: body.emptyState
    property alias placeholder: header.placeholder
    property alias icon: header.icon
    property alias signalIcon: body.signalIcon
    property alias powered: header.powered
    property alias refreshing: header.refreshing
    property alias busy: body.busy
    property alias powerEnabled: header.powerEnabled
    property alias powerAccessory: header.powerAccessory
    property alias powerVisible: header.powerVisible
    property alias refreshEnabled: header.refreshEnabled
    property alias refreshIcon: header.refreshIcon
    property alias focusOnCompleted: header.focusOnCompleted
    property alias iconActionEnabled: header.iconActionEnabled
    property alias iconAccessibleName: header.iconAccessibleName
    readonly property real headerHeight: header.height
    property alias searchActionIcon: header.searchActionIcon
    property alias searchActionToolTip: header.searchActionToolTip
    property alias searchActionEnabled: header.searchActionEnabled
    property alias searchActionActive: header.searchActionActive
    property alias filterText: header.filterText
    property alias status: body.status
    property alias statusSummary: body.statusSummary
    property alias statusTone: body.statusTone
    property alias feedbackScope: body.feedbackScope
    readonly property real feedbackTextWidth: body.feedbackTextWidth
    property int bodySpacing: Theme.verticalSpacing(Theme.spacingSm, densityScale)
    readonly property int resultCount: body.resultCount
    readonly property real delegateHeight: body.delegateHeight
    readonly property bool listFocused: body.listFocused
    readonly property bool searchFocused: header.searchFocused
    readonly property int selectedIndex: chooserController.selectionModel ? chooserController.selectionModel.selectedIndex : 0

    readonly property var controlLocation: FocusLocations.capture(pane, Window.window ? Window.window.activeFocusItem : null)
    property var lastControlLocation: null
    onControlLocationChanged: if (controlLocation) lastControlLocation = controlLocation

    signal querySelectionChanged
    signal iconClicked
    signal searchActionRequested

    function applyFilter(text: string): void {
        chooserController.navigationInteracted();
        body.restoreViewport(null);
        if (chooserController.selectionModel)
            chooserController.selectionModel.queryText = text;
        chooserController.selectFirst();
    }
    function requestRefresh(): void {
        chooserController.refresh();
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Theme.verticalSpacing(Theme.spacingMd, densityScale)

    function sessionState(): var {
        return {selection: header.selectionState(), viewport: body.viewportState(), control: lastControlLocation};
    }
    function restoreSession(state: var): void {
        if (!state)
            return;
        header.restoreSelection(state.selection);
        body.restoreViewport(state.viewport);
    }

    function restoreControl(state: var): bool { return FocusLocations.restore(pane, state); }
    function focusSearch(): void {
        header.focusSearch();
    }
    function insertSearchText(text: string): void {
        header.insertSearchText(text);
    }
    function focusList(): void {
        body.focusList();
    }
    function focusTop(): void {
        body.focusTop();
    }
    function pick(rowIndex: int): void {
        body.pick(rowIndex);
    }
    function toggleDetails(rowIndex: int): void {
        body.toggleDetails(rowIndex);
    }

    ChooserHeader {
        id: header
        uiScale: 1
        onQuerySelectionChanged: pane.querySelectionChanged()
        onFilterEdited: function (text) {
            pane.applyFilter(text);
        }
        onKeyPressed: function (event) {
            pane.chooserController.navigationInteracted();
            pane.chooserController.navigation.handleSearchKey(event);
        }
        onIconClicked: pane.iconClicked()
        onSearchActionRequested: pane.searchActionRequested()
        onPowerRequested: pane.chooserController.setPower()
        onRefreshRequested: pane.requestRefresh()
    }

    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: (item as Item)?.implicitHeight ?? 0
        visible: sourceComponent !== null
        sourceComponent: pane.listOptionsComponent
    }

    ChooserListBody {
        id: body
        Layout.fillWidth: true
        Layout.fillHeight: true
        chooserController: pane.chooserController
        rowDelegate: pane.rowDelegate
        selectedIndex: pane.selectedIndex
        icon: pane.icon
        powered: pane.powered
        bodySpacing: pane.bodySpacing
    }
}
