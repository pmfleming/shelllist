pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui

Item {
    id: pane

    required property WifiController controller
    required property real uiScale

    Layout.fillWidth: true
    Layout.fillHeight: true

    function focusTop() { listFrame.focusTop(); }

    Column {
        anchors.fill: parent
        anchors.leftMargin: Math.round(12 * pane.uiScale)
        spacing: Math.round(6 * pane.uiScale)

        ResultListFrame {
            id: listFrame

            width: parent.width
            height: parent.height - statusPanel.height - parent.spacing
            uiScale: pane.uiScale
            controller: pane.controller
            resultModel: pane.controller.powered ? pane.controller.filteredResultsModel : null
            selectedIndex: pane.controller.selectedIndex
            emptyText: pane.controller.powered ? "No Wi-Fi networks" : "Wi-Fi is off"
            onKeyPressed: function (event) {
                pane.controller.navigation.handleListKey(event);
            }
            rowDelegate: Component {
                NetworkListRow {
                    id: networkRow

                    rowHeight: listFrame.delegateHeight
                    active: !!networkRow.result.state.active
                    name: networkRow.result.title
                    selectedIndex: pane.controller.selectedIndex
                    selectionFocused: listFrame.listFocused
                    detailsOpen: pane.controller.detailsOpen
                    connecting: pane.controller.connection.isConnecting(networkRow.result.payload)
                    progressTick: pane.controller.connection.progressTick
                    onPicked: function (rowIndex) { listFrame.pick(rowIndex); }
                    onDetailsToggled: function (rowIndex) { listFrame.toggleDetails(rowIndex); }
                    onPrimaryRequested: pane.controller.primarySelected()
                }
            }
        }

        StatusPanel {
            id: statusPanel

            width: parent.width
            uiScale: pane.uiScale
            status: pane.controller.status
            signalIcon: true
            powered: pane.controller.powered
            busy: pane.controller.actionInFlight
        }
    }
}
