pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: pane

    required property ChooserController chooserController
    required property Component rowDelegate
    property real densityScale: Theme.densityScale(height + 2 * chooserController.contentVerticalMargin, chooserController.contentVerticalMargin)
    property Component listOptionsComponent: null
    property Component listFooterComponent: null
    property bool preserveViewportOnAppend: false
    readonly property bool listNearEnd: body.listNearEnd
    property var resultModel: null
    property string emptyText: ""
    property string emptyIcon: ""
    property string placeholder: "Search…"
    property string icon: ""
    property bool signalIcon: false
    property bool powered: false
    property bool refreshing: false
    property bool busy: false
    property bool powerEnabled: true
    property alias powerAccessory: header.powerAccessory
    property bool powerVisible: true
    property bool refreshEnabled: true
    property string refreshIcon: "󰑐"
    property bool focusOnCompleted: false
    property bool iconActionEnabled: false
    property string iconAccessibleName: ""
    readonly property real headerHeight: header.height
    property string searchActionIcon: ""
    property string searchActionToolTip: ""
    property bool searchActionEnabled: true
    property string filterText: ""
    property string status: ""
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
        placeholder: pane.placeholder
        icon: pane.icon
        filterText: pane.filterText
        powered: pane.powered
        refreshing: pane.refreshing
        powerEnabled: pane.powerEnabled
        powerVisible: pane.powerVisible
        refreshEnabled: pane.refreshEnabled
        refreshIcon: pane.refreshIcon
        focusOnCompleted: pane.focusOnCompleted
        iconActionEnabled: pane.iconActionEnabled
        iconAccessibleName: pane.iconAccessibleName
        searchActionIcon: pane.searchActionIcon
        searchActionToolTip: pane.searchActionToolTip
        searchActionEnabled: pane.searchActionEnabled
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
        resultModel: pane.resultModel
        listFooterComponent: pane.listFooterComponent
        preserveViewportOnAppend: pane.preserveViewportOnAppend
        selectedIndex: pane.selectedIndex
        emptyText: pane.emptyText
        emptyIcon: pane.emptyIcon
        status: pane.status
        icon: pane.icon
        signalIcon: pane.signalIcon
        powered: pane.powered
        busy: pane.busy
        bodySpacing: pane.bodySpacing
    }
}
