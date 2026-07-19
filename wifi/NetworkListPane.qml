pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui

Item {
    id: pane

    required property WifiController controller

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
        spacing: 6

        Rectangle {
            width: parent.width
            height: parent.height - statusPanel.height - parent.spacing
            radius: Theme.panelRadius
            color: Theme.surface
            border.color: Theme.border
            clip: true

            ListView {
                id: list

                readonly property int visibleRowTarget: Math.max(1, Math.min(count, 15))
                readonly property real delegateHeight: Math.max(42, Math.min(58, height / visibleRowTarget))

                anchors.fill: parent
                clip: true
                model: pane.controller.filteredResults
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
                    detailsOpen: pane.controller.detailsOpen
                    connecting: pane.controller.isConnecting(networkRow.result.payload)
                    progressTick: pane.controller.connectingProgressTick
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
            height: 38
            radius: Theme.cardRadius
            color: Theme.surfaceRaised
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                SignalIcon {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 16
                    level: 1
                    iconColor: Theme.mutedText
                }

                Text {
                    Layout.fillWidth: true
                    text: pane.controller.status
                    color: pane.controller.actionInFlight ? Theme.accent : Theme.subtleText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    visible: pane.controller.scanInFlight
                    text: "󰑐"
                    color: Theme.mutedText
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 16

                    NumberAnimation on rotation {
                        running: pane.controller.scanInFlight && !Theme.noAnimations
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                }
            }
        }
    }
}
