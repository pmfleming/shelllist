pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: pane

    required property ChooserController chooserController
    required property Component rowDelegate
    required property real densityScale
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
    property bool focusOnCompleted: false
    property bool iconActionEnabled: false
    property string filterText: ""
    property string status: ""
    property real listInset: 0
    property int bodySpacing: Math.round(Theme.spacingSm * densityScale)
    property Component toolbarComponent: null
    property int toolbarHeight: Math.round(Theme.controlHeight * densityScale)
    readonly property real delegateHeight: listFrame.delegateHeight
    readonly property bool listFocused: listFrame.listFocused
    readonly property int selectedIndex: chooserController.selectionModel
        ? chooserController.selectionModel.selectedIndex : 0

    signal filterEdited(string text)
    signal searchKeyPressed(var event)
    signal listKeyPressed(var event)
    signal iconClicked
    signal powerRequested
    signal refreshRequested

    onFilterEdited: function (text) {
        if (chooserController.selectionModel)
            chooserController.selectionModel.queryText = text;
        chooserController.selectFirst();
    }
    onSearchKeyPressed: function (event) { chooserController.navigation.handleSearchKey(event); }
    onListKeyPressed: function (event) { chooserController.navigation.handleListKey(event); }
    onPowerRequested: chooserController.setPower()
    onRefreshRequested: chooserController.refresh()

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Math.round(Theme.spacingMd * densityScale)

    function focusSearch() { header.focusSearch(); }
    function focusTop() { listFrame.focusTop(); }
    function pick(rowIndex) { listFrame.pick(rowIndex); }
    function toggleDetails(rowIndex) { listFrame.toggleDetails(rowIndex); }

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
        focusOnCompleted: pane.focusOnCompleted
        iconActionEnabled: pane.iconActionEnabled
        onFilterEdited: function (text) { pane.filterEdited(text); }
        onKeyPressed: function (event) { pane.searchKeyPressed(event); }
        onIconClicked: pane.iconClicked()
        onPowerRequested: pane.powerRequested()
        onRefreshRequested: pane.refreshRequested()
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: pane.listInset
            spacing: pane.bodySpacing

            ResultListFrame {
                id: listFrame
                Layout.fillWidth: true
                Layout.fillHeight: true
                uiScale: pane.densityScale
                controller: pane.chooserController
                resultModel: pane.resultModel
                selectedIndex: pane.selectedIndex
                emptyText: pane.emptyText
                rowDelegate: pane.rowDelegate
                onKeyPressed: function (event) { pane.listKeyPressed(event); }
            }

            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: active ? pane.toolbarHeight : 0
                active: pane.toolbarComponent !== null
                sourceComponent: pane.toolbarComponent
            }

            StatusPanel {
                Layout.fillWidth: true
                uiScale: pane.densityScale
                status: pane.status
                icon: pane.icon
                signalIcon: pane.signalIcon
                powered: pane.powered
                busy: pane.busy
            }
        }
    }
}
