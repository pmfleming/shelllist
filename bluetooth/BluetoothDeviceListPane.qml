pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: pane

    required property BluetoothController controller
    Layout.preferredWidth: 404
    Layout.fillHeight: true
    spacing: 10

    function focusSearch() { search.forceActiveFocus(); }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        spacing: 10

        Text {
            text: "󰂯"
            color: pane.controller.powered ? Ui.Theme.accent : Ui.Theme.mutedText
            font.family: Ui.Theme.iconFontFamily
            font.pixelSize: 24
        }
        TextInput {
            id: search
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: pane.controller.filterText
            color: Ui.Theme.text
            selectionColor: Ui.Theme.accent
            font.family: Ui.Theme.fontFamily
            font.pixelSize: 15
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            onTextEdited: pane.controller.filterText = text
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Down) { pane.controller.moveSelection(1); event.accepted = true; }
                else if (event.key === Qt.Key_Up) { pane.controller.moveSelection(-1); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { pane.controller.primarySelected(); event.accepted = true; }
                else if (event.key === Qt.Key_Right && cursorPosition === text.length) { pane.controller.detailsOpen = true; event.accepted = true; }
            }
        }
        Rectangle {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 28
            radius: 14
            color: pane.controller.powered ? Ui.Theme.accent : Ui.Theme.surfaceRaised
            border.color: pane.controller.powered ? Ui.Theme.accent : Ui.Theme.border
            Text {
                anchors.centerIn: parent
                text: pane.controller.powered ? "ON" : "OFF"
                color: pane.controller.powered ? Ui.Theme.window : Ui.Theme.subtleText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 11
                font.bold: true
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pane.controller.setPower() }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 520
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border
        clip: true

        ListView {
            id: deviceList
            anchors.fill: parent
            model: pane.controller.filteredResultsModel
            currentIndex: pane.controller.selectedIndex
            clip: true
            delegate: Rectangle {
                id: deviceRow
                required property int index
                required property var resultData
                readonly property var device: resultData.payload || ({})
                readonly property bool selected: index === pane.controller.selectedIndex
                width: deviceList.width
                height: 58
                color: selected ? Ui.Theme.selected : "transparent"
                border.color: selected ? Ui.Theme.strongBorder : "transparent"
                radius: selected ? Ui.Theme.cardRadius : 0
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 14
                    spacing: 11
                    Text {
                        Layout.preferredWidth: 26
                        text: deviceRow.resultData.icon || "󰂯"
                        color: deviceRow.device.connected ? Ui.Theme.active : Ui.Theme.mutedText
                        font.family: Ui.Theme.iconFontFamily
                        font.pixelSize: 20
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { Layout.fillWidth: true; text: deviceRow.resultData.title; color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 14; font.bold: deviceRow.device.connected; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: deviceRow.resultData.subtitle; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
                    }
                    Text { text: "󰅂"; color: deviceRow.selected ? Ui.Theme.accent : Ui.Theme.mutedText; font.family: Ui.Theme.iconFontFamily; font.pixelSize: 17 }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: pane.controller.selectedIndex = deviceRow.index
                    onDoubleClicked: pane.controller.primarySelected()
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: deviceList.count === 0
            text: pane.controller.powered ? "No devices · press F5 to scan" : "Bluetooth is off"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: 13
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        Text { Layout.fillWidth: true; text: pane.controller.status; color: pane.controller.actionInFlight ? Ui.Theme.accent : Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
        Text { text: pane.controller.scanning ? "󰑐" : "F5 Scan"; color: Ui.Theme.mutedText; font.family: pane.controller.scanning ? Ui.Theme.iconFontFamily : Ui.Theme.fontFamily; font.pixelSize: 12; NumberAnimation on rotation { running: pane.controller.scanning && !Ui.Theme.noAnimations; loops: Animation.Infinite; from: 0; to: 360; duration: 900 } }
    }
}
