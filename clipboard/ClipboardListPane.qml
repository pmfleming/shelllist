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
            id: "pause", label: pane.controller.settings.capture_paused ? "Resume" : "Pause", icon: "󰏤", shortcut: "",
            visible: true, enabled: !pane.controller.actionInFlight,
            presentation: { group: "toolbar", tone: pane.controller.settings.capture_paused ? "warning" : "normal", width: 104 }
        }, {
            id: "private", label: "Private", icon: "󰌾", shortcut: "",
            visible: !pane.controller.settings.capture_paused, enabled: !pane.controller.actionInFlight,
            presentation: { group: "toolbar", tone: "normal", width: 104 }
        }, {
            id: "retention", label: pane.controller.settings.max_entries + " kept", icon: "󰓦", shortcut: "",
            visible: true, enabled: !pane.controller.actionInFlight,
            presentation: { group: "toolbar", tone: "normal", width: 112 }
        }, {
            id: "wipe", label: "Clear", icon: "󰆴", shortcut: "",
            visible: true, enabled: !pane.controller.actionInFlight,
            presentation: { group: "toolbar", tone: "danger", width: 94 }
        }]
        alignRight: false
        onTriggered: function (actionId) {
            if (actionId === "pause") pane.controller.toggleCapturePaused(false);
            else if (actionId === "private") pane.controller.toggleCapturePaused(true);
            else if (actionId === "retention") pane.controller.cycleRetention();
            else pane.controller.requestWipe();
        }
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
