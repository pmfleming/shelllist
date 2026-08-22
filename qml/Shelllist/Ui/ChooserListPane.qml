pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: pane

    required property ChooserController chooserController
    required property Component rowDelegate
    property real densityScale: Theme.densityScale(
        height + 2 * chooserController.contentVerticalMargin,
        chooserController.contentVerticalMargin)
    property var resultModel: null
    property string emptyText: ""
    property string placeholder: "Search…"
    property string icon: ""
    property bool signalIcon: false
    property bool powered: false
    property bool refreshing: false
    property bool busy: false
    property bool powerEnabled: true
    property bool refreshEnabled: true
    property string refreshIcon: "󰑐"
    property var refreshHandler: null
    property bool focusOnCompleted: false
    property bool iconActionEnabled: false
    property string searchActionIcon: ""
    property string searchActionToolTip: ""
    property bool searchActionEnabled: true
    property string filterText: ""
    property string status: ""
    property real listInset: 0
    property int bodySpacing: Theme.verticalSpacing(Theme.spacingSm, densityScale)
    property Component toolbarComponent: null
    property int toolbarHeight: Math.round(Theme.controlHeight * densityScale)
    readonly property real delegateHeight: body.delegateHeight
    readonly property bool listFocused: body.listFocused
    readonly property int selectedIndex: chooserController.selectionModel
        ? chooserController.selectionModel.selectedIndex : 0

    signal iconClicked
    signal searchActionRequested

    function applyFilter(text: string): void {
        if (chooserController.selectionModel)
            chooserController.selectionModel.queryText = text;
        chooserController.selectFirst();
    }
    function requestRefresh(): void {
        if (refreshHandler)
            refreshHandler();
        else
            chooserController.refresh();
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Theme.verticalSpacing(Theme.spacingMd, densityScale)

    function focusSearch(): void { header.focusSearch(); }
    function focusTop(): void { body.focusTop(); }
    function pick(rowIndex: int): void { body.pick(rowIndex); }
    function toggleDetails(rowIndex: int): void { body.toggleDetails(rowIndex); }

    ChooserHeader {
        id: header
        uiScale: pane.densityScale
        placeholder: pane.placeholder
        icon: pane.icon
        signalIcon: pane.signalIcon
        filterText: pane.filterText
        powered: pane.powered
        refreshing: pane.refreshing
        powerEnabled: pane.powerEnabled
        refreshEnabled: pane.refreshEnabled
        refreshIcon: pane.refreshIcon
        focusOnCompleted: pane.focusOnCompleted
        iconActionEnabled: pane.iconActionEnabled
        searchActionIcon: pane.searchActionIcon
        searchActionToolTip: pane.searchActionToolTip
        searchActionEnabled: pane.searchActionEnabled
        onFilterEdited: function (text) { pane.applyFilter(text); }
        onKeyPressed: function (event) { pane.chooserController.navigation.handleSearchKey(event); }
        onIconClicked: pane.iconClicked()
        onSearchActionRequested: pane.searchActionRequested()
        onPowerRequested: pane.chooserController.setPower()
        onRefreshRequested: pane.requestRefresh()
    }

    ChooserListBody {
        id: body
        Layout.fillWidth: true
        Layout.fillHeight: true
        chooserController: pane.chooserController
        rowDelegate: pane.rowDelegate
        densityScale: pane.densityScale
        resultModel: pane.resultModel
        selectedIndex: pane.selectedIndex
        emptyText: pane.emptyText
        toolbarComponent: pane.toolbarComponent
        toolbarHeight: pane.toolbarHeight
        status: pane.status
        icon: pane.icon
        signalIcon: pane.signalIcon
        powered: pane.powered
        busy: pane.busy
        listInset: pane.listInset
        bodySpacing: pane.bodySpacing
    }
}
