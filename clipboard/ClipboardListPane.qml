pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: pane

    required property ClipboardController controller
    required property real uiScale
    Layout.fillHeight: true
    spacing: Math.round(10 * uiScale)

    function focusSearch() { header.focusSearch(); }
    function focusTop() {
        controller.selectedIndex = 0;
        listFrame.focusTop();
    }

    Ui.ChooserHeader {
        id: header
        uiScale: pane.uiScale
        placeholder: "Search clipboard…"
        icon: "󰅇"
        filterText: pane.controller.filterText
        powered: true
        refreshing: pane.controller.refreshInFlight
        powerEnabled: false
        refreshEnabled: !pane.controller.refreshInFlight
        onFilterEdited: function (text) { pane.controller.filterText = text; }
        onRefreshRequested: pane.controller.refresh()
        onKeyPressed: function (event) {
            if (event.key === Qt.Key_Down) {
                pane.controller.selectedIndex = 0;
                listFrame.focusTop();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                pane.controller.openDetails();
                event.accepted = true;
            }
        }
    }

    Ui.ResultListFrame {
        id: listFrame
        Layout.fillWidth: true
        Layout.fillHeight: true
        uiScale: pane.uiScale
        resultModel: pane.controller.filteredResultsModel
        selectedIndex: pane.controller.selectedIndex
        emptyText: pane.controller.refreshInFlight ? "Loading clipboard history…" : "Clipboard history is empty"
        onKeyPressed: function (event) {
            if (event.key === Qt.Key_Down) {
                pane.controller.moveSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                if (pane.controller.selectedIndex === 0)
                    header.focusSearch();
                else
                    pane.controller.moveSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                pane.controller.openDetails();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                pane.controller.closeDetails();
                event.accepted = true;
            }
        }
        rowDelegate: Component {
            ClipboardListRow {
                rowHeight: listFrame.delegateHeight
                uiScale: pane.uiScale
                selectedIndex: pane.controller.selectedIndex
                selectionFocused: listFrame.listFocused
                detailsOpen: pane.controller.detailsOpen
                onPicked: function (rowIndex) {
                    pane.controller.selectedIndex = rowIndex;
                    listFrame.focusList();
                }
                onDetailsToggled: function (rowIndex) {
                    pane.controller.selectedIndex = rowIndex;
                    pane.controller.toggleDetails();
                    listFrame.focusList();
                }
            }
        }
    }

    Ui.ActionToolbar {
        Layout.fillWidth: true
        actions: [{
            id: "wipe", label: "Clear history", icon: "󰆴", shortcut: "",
            visible: true, enabled: !pane.controller.actionInFlight,
            presentation: { group: "toolbar", tone: "danger", width: 132 }
        }]
        alignRight: false
        onTriggered: pane.controller.requestWipe()
    }

    Ui.StatusPanel {
        Layout.fillWidth: true
        uiScale: pane.uiScale
        status: pane.controller.status
        icon: "󰅇"
        powered: true
        busy: pane.controller.refreshInFlight
    }
}
