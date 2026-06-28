import QtQuick
import QtQuick.Layouts
import "Wifi.js" as Wifi

Rectangle {
    id: pane

    required property var controller

    Layout.preferredWidth: 425
    Layout.fillHeight: true
    radius: 12
    color: "#0f172a"
    border.color: "#1f2a3a"

    function focusTop() {
        pane.controller.selectedIndex = 0;
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
            height: parent.height
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
                name: Wifi.networkName(modelData)
                selectedIndex: pane.controller.selectedIndex
                detailsOpen: pane.controller.detailsOpen
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
    }
}
