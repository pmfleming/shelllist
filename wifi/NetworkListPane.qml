pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: pane

    required property var controller

    Layout.preferredWidth: 425
    Layout.fillHeight: true
    radius: Theme.panelRadius
    color: Theme.surface
    border.color: Theme.border

    function focusTop() {
        controller.selectedIndex = 0;
        list.forceActiveFocus();
        list.positionViewAtBeginning();
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        ListView {
            id: list
            width: parent.width
            height: parent.height - statusLine.height - parent.spacing
            clip: true
            model: pane.controller.filteredNetworks
            spacing: 3
            currentIndex: pane.controller.selectedIndex
            activeFocusOnTab: true
            Keys.onPressed: function (event) {
                pane.controller.handleListKey(event);
            }
            onCurrentIndexChanged: {
                if (currentIndex >= 0 && count > 0)
                    positionViewAtIndex(currentIndex, ListView.Contain);
            }

            delegate: NetworkListRow {
                active: pane.controller.isActive(modelData)
                name: pane.controller.networkName(modelData)
                selectedIndex: pane.controller.selectedIndex
                detailsOpen: pane.controller.detailsOpen
                connecting: pane.controller.isConnecting(modelData)
                progressTick: pane.controller.connectingProgressTick
                onPicked: function (rowIndex) {
                    pane.controller.selectedIndex = rowIndex;
                    list.forceActiveFocus();
                }
                onDetailsToggled: function (rowIndex) {
                    pane.controller.selectedIndex = rowIndex;
                    pane.controller.toggleDetailsPane();
                    list.forceActiveFocus();
                }
                onConnectRequested: pane.controller.primarySelected()
            }
        }

        Text {
            id: statusLine
            width: parent.width
            height: 24
            text: pane.controller.status
            color: pane.controller.actionInFlight ? Theme.accent : Theme.subtleText
            font.pixelSize: 12
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
