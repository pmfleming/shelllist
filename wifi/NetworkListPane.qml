pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui

Item {
    id: pane

    required property WifiController controller
    required property real uiScale

    Layout.fillWidth: true
    Layout.fillHeight: true

    function focusTop() {
        controller.selectedIndex = 0;
        list.forceActiveFocus();
        list.positionViewAtBeginning();
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: 12
        spacing: Math.round(6 * pane.uiScale)

        Rectangle {
            width: parent.width
            height: parent.height - statusPanel.height - parent.spacing
            radius: Theme.panelRadius
            color: Theme.surface
            border.color: Theme.border
            clip: true

            ListView {
                id: list

                readonly property real delegateHeight: Theme.listDelegateHeight(height)

                anchors.fill: parent
                clip: true
                model: pane.controller.filteredResultsModel
                spacing: 0
                currentIndex: pane.controller.selectedIndex
                activeFocusOnTab: true
                Keys.onPressed: function (event) {
                    pane.controller.navigation.handleListKey(event);
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && count > 0)
                        positionViewAtIndex(currentIndex, ListView.Contain);
                }

                delegate: NetworkListRow {
                    id: networkRow

                    rowHeight: list.delegateHeight
                    active: !!networkRow.result.state.active
                    name: networkRow.result.title
                    selectedIndex: pane.controller.selectedIndex
                    selectionFocused: list.activeFocus
                    detailsOpen: pane.controller.detailsOpen
                    connecting: pane.controller.connection.isConnecting(networkRow.result.payload)
                    progressTick: pane.controller.connection.progressTick
                    onPicked: function (rowIndex) {
                        pane.controller.selectedIndex = rowIndex;
                        list.forceActiveFocus();
                    }
                    onDetailsToggled: function (rowIndex) {
                        pane.controller.selectedIndex = rowIndex;
                        pane.controller.navigation.toggleDetails();
                        list.forceActiveFocus();
                    }
                    onConnectRequested: pane.controller.primarySelected()
                }
            }
        }

        Rectangle {
            id: statusPanel

            width: parent.width
            height: Math.round(Theme.statusHeight * pane.uiScale)
            radius: Theme.cardRadius
            color: Theme.surfaceRaised
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(14 * pane.uiScale)
                anchors.rightMargin: Math.round(14 * pane.uiScale)
                spacing: Math.round(10 * pane.uiScale)

                SignalIcon {
                    Layout.preferredWidth: Math.round(18 * pane.uiScale)
                    Layout.preferredHeight: Math.round(16 * pane.uiScale)
                    level: 1
                    iconColor: Theme.mutedText
                }

                Text {
                    Layout.fillWidth: true
                    text: pane.controller.status
                    color: pane.controller.actionInFlight ? Theme.accent : Theme.subtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(11, Math.round(12 * pane.uiScale))
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
