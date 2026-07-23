pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: pane

    required property BluetoothController controller
    required property real uiScale

    Layout.fillHeight: true
    spacing: Math.round(10 * uiScale)

    function scaled(value) {
        return Math.round(value * uiScale);
    }
    function focusSearch() {
        header.focusSearch();
    }
    function focusTop() {
        controller.selectedIndex = 0;
        listFrame.focusTop();
    }

    Ui.ChooserHeader {
        id: header
        uiScale: pane.uiScale
        placeholder: "Search devices…"
        icon: "󰂯"
        filterText: pane.controller.filterText
        powered: pane.controller.powered
        refreshing: pane.controller.refreshInFlight
        powerEnabled: !pane.controller.actionInFlight
        refreshEnabled: pane.controller.powered && !pane.controller.actionInFlight
        onFilterEdited: function (text) {
            pane.controller.filterText = text;
            pane.controller.selectedIndex = 0;
        }
        onKeyPressed: function (event) {
            pane.controller.navigation.handleSearchKey(event);
        }
        onPowerRequested: pane.controller.setPower()
        onRefreshRequested: pane.controller.toggleScan()
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Column {
            anchors.fill: parent
            anchors.leftMargin: pane.scaled(12)
            spacing: pane.scaled(6)

            Ui.ResultListFrame {
                id: listFrame

                width: parent.width
                height: parent.height - statusPanel.height - parent.spacing
                uiScale: pane.uiScale
                resultModel: pane.controller.filteredResultsModel
                selectedIndex: pane.controller.selectedIndex
                emptyText: pane.controller.powered ? "No Bluetooth devices" : "Bluetooth is off"
                onKeyPressed: function (event) {
                    pane.controller.navigation.handleListKey(event);
                }
                rowDelegate: Component {
                    BluetoothDeviceListRow {
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
                            pane.controller.navigation.toggleDetails();
                            listFrame.focusList();
                        }
                        onPrimaryRequested: pane.controller.primarySelected()
                    }
                }
            }

            Ui.StatusPanel {
                id: statusPanel

                width: parent.width
                uiScale: pane.uiScale
                status: pane.controller.status
                icon: "󰂯"
                powered: pane.controller.powered
                busy: pane.controller.actionInFlight
            }
        }
    }
}
