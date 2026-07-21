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

    function scaled(value) { return Math.round(value * uiScale); }
    function focusSearch() { header.focusSearch(); }
    function focusTop() {
        controller.selectedIndex = 0;
        deviceList.forceActiveFocus();
        deviceList.positionViewAtBeginning();
    }

    BluetoothHeader {
        id: header
        uiScale: pane.uiScale
        filterText: pane.controller.filterText
        powered: pane.controller.powered
        scanning: pane.controller.scanning
        powerEnabled: !pane.controller.actionInFlight
        scanEnabled: pane.controller.powered && !pane.controller.actionInFlight
        onFilterEdited: function (text) {
            pane.controller.filterText = text;
            pane.controller.selectedIndex = 0;
        }
        onKeyPressed: function (event) { pane.controller.navigation.handleSearchKey(event); }
        onPowerRequested: pane.controller.setPower()
        onScanRequested: pane.controller.toggleScan()
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Column {
            anchors.fill: parent
            anchors.leftMargin: pane.scaled(12)
            spacing: pane.scaled(6)

            Rectangle {
                width: parent.width
                height: parent.height - statusPanel.height - parent.spacing
                radius: Ui.Theme.panelRadius
                color: Ui.Theme.surface
                border.color: Ui.Theme.border
                clip: true

                ListView {
                    id: deviceList

                    readonly property real delegateHeight: Ui.Theme.listDelegateHeight(height)

                    anchors.fill: parent
                    clip: true
                    model: pane.controller.filteredResultsModel
                    currentIndex: pane.controller.selectedIndex
                    activeFocusOnTab: true
                    Keys.onPressed: function (event) { pane.controller.navigation.handleListKey(event); }
                    onCurrentIndexChanged: if (currentIndex >= 0 && count > 0) positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: BluetoothDeviceListRow {
                        rowHeight: deviceList.delegateHeight
                        uiScale: pane.uiScale
                        selectedIndex: pane.controller.selectedIndex
                        detailsOpen: pane.controller.detailsOpen
                        onPicked: function (rowIndex) {
                            pane.controller.selectedIndex = rowIndex;
                            deviceList.forceActiveFocus();
                        }
                        onDetailsToggled: function (rowIndex) {
                            pane.controller.selectedIndex = rowIndex;
                            pane.controller.navigation.toggleDetails();
                            deviceList.forceActiveFocus();
                        }
                        onPrimaryRequested: pane.controller.primarySelected()
                    }
                }

                Ui.CenteredMessage {
                    visible: deviceList.count === 0
                    text: pane.controller.powered ? "No Bluetooth devices" : "Bluetooth is off"
                    font.pixelSize: Math.max(Ui.Theme.fontSizeCaption, pane.scaled(Ui.Theme.fontSizeBody))
                }
            }

            Rectangle {
                id: statusPanel

                width: parent.width
                height: pane.scaled(Ui.Theme.statusHeight)
                radius: Ui.Theme.cardRadius
                color: Ui.Theme.surfaceRaised
                border.color: Ui.Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: pane.scaled(Ui.Theme.contentMargin)
                    anchors.rightMargin: pane.scaled(Ui.Theme.contentMargin)
                    spacing: pane.scaled(10)

                    Text {
                        Layout.preferredWidth: pane.scaled(Ui.Theme.iconSize)
                        text: "󰂯"
                        color: pane.controller.powered ? Ui.Theme.accent : Ui.Theme.mutedText
                        font.family: Ui.Theme.iconFontFamily
                        font.pixelSize: Math.max(Ui.Theme.iconSizeSmall, pane.scaled(Ui.Theme.iconSize))
                    }

                    Text {
                        Layout.fillWidth: true
                        text: pane.controller.status
                        color: pane.controller.actionInFlight ? Ui.Theme.accent : Ui.Theme.subtleText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Math.max(10, pane.scaled(Ui.Theme.fontSizeCaption))
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        visible: pane.controller.scanning
                        text: "󰑐"
                        color: Ui.Theme.mutedText
                        font.family: Ui.Theme.iconFontFamily
                        font.pixelSize: Math.max(Ui.Theme.iconSizeSmall, pane.scaled(Ui.Theme.iconSize))

                        NumberAnimation on rotation {
                            running: pane.controller.scanning && !Ui.Theme.noAnimations
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: Ui.Theme.spinnerDuration
                        }
                    }
                }
            }
        }
    }
}
