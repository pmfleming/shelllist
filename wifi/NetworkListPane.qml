import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
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
            model: controller.filteredNetworks
            spacing: 3
            currentIndex: controller.selectedIndex
            activeFocusOnTab: true
            Keys.onPressed: function (event) {
                controller.handleListKey(event);
            }
            onCurrentIndexChanged: {
                if (currentIndex >= 0 && count > 0)
                    positionViewAtIndex(currentIndex, ListView.Contain);
            }

            delegate: NetworkListRow {
                active: controller.isActive(modelData)
                name: controller.networkName(modelData)
                selectedIndex: controller.selectedIndex
                detailsOpen: controller.detailsOpen
                connecting: controller.isConnecting(modelData)
                progressTick: controller.connectingProgressTick
                onPicked: function (rowIndex) {
                    controller.selectedIndex = rowIndex;
                    list.forceActiveFocus();
                }
                onDetailsToggled: function (rowIndex) {
                    controller.selectedIndex = rowIndex;
                    controller.toggleDetailsPane();
                    list.forceActiveFocus();
                }
                onConnectRequested: controller.primarySelected()
            }
        }

        Text {
            id: statusLine
            width: parent.width
            height: 24
            text: controller.status
            color: controller.actionInFlight ? Theme.accent : Theme.subtleText
            font.pixelSize: 12
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
