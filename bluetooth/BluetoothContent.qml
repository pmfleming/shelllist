pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: content

    required property BluetoothController controller
    required property BluetoothWindowHost windowHost
    property bool confirmRemove: false

    anchors.fill: parent
    radius: Ui.Theme.windowRadius
    color: Ui.Theme.window
    border.color: Ui.Theme.strongBorder
    border.width: 1

    function focusSearch() { search.forceActiveFocus(); }
    function toggleDetails() { if (controller.hasSelection) controller.detailsOpen = !controller.detailsOpen; }
    function requestRemove() { confirmRemove = true; }

    Connections {
        target: content.controller
        function onFocusSearchRequested() { Qt.callLater(content.focusSearch); }
        function onSelectedResultChanged() {
            content.confirmRemove = false;
            renameInput.text = content.controller.selectedDevice.name || "";
        }
    }

    Shortcut { sequence: "Up"; enabled: !content.controller.pairingPromptOpen; onActivated: content.controller.moveSelection(-1) }
    Shortcut { sequence: "Down"; enabled: !content.controller.pairingPromptOpen; onActivated: content.controller.moveSelection(1) }
    Shortcut { sequence: "Enter"; enabled: !content.confirmRemove && !content.controller.pairingPromptOpen && !renameInput.activeFocus; onActivated: content.controller.primarySelected() }
    Shortcut { sequence: "Right"; enabled: content.controller.hasSelection && !content.controller.pairingPromptOpen; onActivated: content.controller.detailsOpen = true }
    Shortcut { sequence: "Left"; enabled: content.controller.detailsOpen && !content.controller.pairingPromptOpen; onActivated: content.controller.detailsOpen = false }
    Shortcut { sequence: "F5"; enabled: !content.controller.pairingPromptOpen; onActivated: content.controller.toggleScan() }
    Shortcut {
        sequence: "Escape"
        enabled: !content.controller.pairingPromptOpen
        onActivated: {
            if (content.controller.canCancelOperation)
                content.controller.cancelActiveOperation();
            else if (content.confirmRemove)
                content.confirmRemove = false;
            else if (content.controller.detailsOpen)
                content.controller.detailsOpen = false;
            else
                content.windowHost.closeRequested();
        }
    }

    component ActionButton: Rectangle {
        id: actionButton
        required property string label
        property bool danger: false
        property bool available: true
        signal clicked
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: Ui.Theme.cardRadius
        color: danger ? Ui.Theme.mix(Ui.Theme.danger, Ui.Theme.surface, 0.82) : Ui.Theme.surfaceRaised
        border.color: danger ? Ui.Theme.danger : Ui.Theme.border
        opacity: available ? 1 : 0.45
        Text {
            anchors.centerIn: parent
            text: actionButton.label
            color: actionButton.danger ? Ui.Theme.danger : Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
        }
        MouseArea {
            anchors.fill: parent
            enabled: actionButton.available
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        ColumnLayout {
            Layout.preferredWidth: 404
            Layout.fillHeight: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                spacing: 10

                Text {
                    text: "󰂯"
                    color: content.controller.powered ? Ui.Theme.accent : Ui.Theme.mutedText
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: 24
                }
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: content.controller.filterText
                    color: Ui.Theme.text
                    selectionColor: Ui.Theme.accent
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: 15
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    onTextEdited: content.controller.filterText = text
                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Down) { content.controller.moveSelection(1); event.accepted = true; }
                        else if (event.key === Qt.Key_Up) { content.controller.moveSelection(-1); event.accepted = true; }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { content.controller.primarySelected(); event.accepted = true; }
                        else if (event.key === Qt.Key_Right && cursorPosition === text.length) { content.controller.detailsOpen = true; event.accepted = true; }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 28
                    radius: 14
                    color: content.controller.powered ? Ui.Theme.accent : Ui.Theme.surfaceRaised
                    border.color: content.controller.powered ? Ui.Theme.accent : Ui.Theme.border
                    Text {
                        anchors.centerIn: parent
                        text: content.controller.powered ? "ON" : "OFF"
                        color: content.controller.powered ? Ui.Theme.window : Ui.Theme.subtleText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: content.controller.setPower() }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Ui.Theme.panelRadius
                color: Ui.Theme.surface
                border.color: Ui.Theme.border
                clip: true

                ListView {
                    id: deviceList
                    anchors.fill: parent
                    model: content.controller.filteredResults
                    currentIndex: content.controller.selectedIndex
                    clip: true
                    delegate: Rectangle {
                        id: deviceRow
                        required property int index
                        required property var modelData
                        readonly property var device: modelData.payload || ({})
                        readonly property bool selected: index === content.controller.selectedIndex
                        width: ListView.view.width
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
                                text: deviceRow.device.connected ? "󰂱" : "󰂯"
                                color: deviceRow.device.connected ? Ui.Theme.active : Ui.Theme.mutedText
                                font.family: Ui.Theme.iconFontFamily
                                font.pixelSize: 20
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { Layout.fillWidth: true; text: deviceRow.modelData.title; color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 14; font.bold: deviceRow.device.connected; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: deviceRow.modelData.subtitle; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
                            }
                            Text {
                                text: "󰅂"
                                color: deviceRow.selected ? Ui.Theme.accent : Ui.Theme.mutedText
                                font.family: Ui.Theme.iconFontFamily
                                font.pixelSize: 17
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: content.controller.selectedIndex = deviceRow.index
                            onDoubleClicked: content.controller.primarySelected()
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: deviceList.count === 0
                    text: content.controller.powered ? "No devices · press F5 to scan" : "Bluetooth is off"
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: 13
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                Text { Layout.fillWidth: true; text: content.controller.status; color: content.controller.actionInFlight ? Ui.Theme.accent : Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
                Text { text: content.controller.scanning ? "󰑐" : "F5 Scan"; color: Ui.Theme.mutedText; font.family: content.controller.scanning ? Ui.Theme.iconFontFamily : Ui.Theme.fontFamily; font.pixelSize: 12; NumberAnimation on rotation { running: content.controller.scanning && !Ui.Theme.noAnimations; loops: Animation.Infinite; from: 0; to: 360; duration: 900 } }
            }
        }

        Rectangle {
            visible: content.controller.detailsOpen
            Layout.preferredWidth: 348
            Layout.fillHeight: true
            radius: Ui.Theme.panelRadius
            color: Ui.Theme.surface
            border.color: Ui.Theme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 10

                Text { Layout.fillWidth: true; text: content.controller.selectedResult ? content.controller.selectedResult.title : "Bluetooth device"; color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: content.controller.selectedResult ? content.controller.selectedResult.subtitle : ""; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 12 }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.border }
                Text { text: "Paired        " + (content.controller.selectedDevice.paired ? "Yes" : "No"); color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 13 }
                Text { text: "Trusted       " + (content.controller.selectedDevice.trusted ? "Yes" : "No"); color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 13 }
                Text { text: "In range      " + (content.controller.selectedDevice.present ? "Yes" : "No"); color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 13 }
                Text {
                    visible: !!content.controller.activeAudioProfile.label
                    Layout.fillWidth: true
                    text: "Audio          " + (content.controller.activeAudioProfile.codec || content.controller.activeAudioProfile.label)
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Text {
                    visible: !!(content.controller.selectedAudio.profiles && content.controller.selectedAudio.profiles.length)
                    text: content.controller.selectedAudio.profiles.length + " audio profiles available"
                    color: Ui.Theme.subtleText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: 11
                }
                Text { text: "Device name"; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11 }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: Ui.Theme.cardRadius
                    color: Ui.Theme.surfaceRaised
                    border.color: renameInput.activeFocus ? Ui.Theme.accent : Ui.Theme.border
                    TextInput {
                        id: renameInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        text: content.controller.selectedDevice.name || ""
                        maximumLength: 248
                        verticalAlignment: TextInput.AlignVCenter
                        color: Ui.Theme.text
                        selectionColor: Ui.Theme.accent
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: 13
                        clip: true
                        onAccepted: content.controller.renameSelected(text)
                    }
                }
                ActionButton {
                    label: "Save device name"
                    available: !!(content.controller.selectedDevice.capabilities && content.controller.selectedDevice.capabilities.can_rename)
                        && renameInput.text.trim().length > 0
                        && renameInput.text.trim() !== (content.controller.selectedDevice.name || "")
                        && !content.controller.actionInFlight
                    onClicked: content.controller.renameSelected(renameInput.text)
                }
                Item { Layout.fillHeight: true }

                ActionButton { visible: !content.controller.canCancelOperation; label: content.controller.selectedDevice.connected ? "Disconnect" : (content.controller.selectedDevice.paired ? "Connect" : "Pair"); available: content.controller.hasSelection && !content.controller.actionInFlight; onClicked: content.controller.primarySelected() }
                ActionButton { visible: content.controller.canCancelOperation; label: "Cancel operation"; danger: true; onClicked: content.controller.cancelActiveOperation() }
                ActionButton { label: (content.controller.selectedDevice.trusted ? "Disable" : "Enable") + " trust"; available: !!(content.controller.selectedDevice.capabilities && content.controller.selectedDevice.capabilities.can_trust); onClicked: content.controller.triggerAction("trusted") }
                ActionButton { visible: content.controller.selectedDevice.wake_allowed !== null && content.controller.selectedDevice.wake_allowed !== undefined; label: (content.controller.selectedDevice.wake_allowed ? "Disable" : "Enable") + " wake"; available: !!(content.controller.selectedDevice.capabilities && content.controller.selectedDevice.capabilities.can_wake); onClicked: content.controller.triggerAction("wake") }
                ActionButton { label: content.controller.selectedDevice.blocked ? "Unblock device" : "Block device"; danger: !content.controller.selectedDevice.blocked; available: !!(content.controller.selectedDevice.capabilities && content.controller.selectedDevice.capabilities.can_block); onClicked: content.controller.triggerAction("blocked") }
                ActionButton { visible: !content.confirmRemove; label: "Remove device"; danger: true; available: !!(content.controller.selectedDevice.capabilities && content.controller.selectedDevice.capabilities.can_remove); onClicked: content.requestRemove() }
                RowLayout {
                    visible: content.confirmRemove
                    Layout.fillWidth: true
                    ActionButton { label: "Cancel"; onClicked: content.confirmRemove = false }
                    ActionButton { label: "Remove"; danger: true; onClicked: { content.confirmRemove = false; content.controller.triggerAction("remove"); } }
                }
                Text { Layout.fillWidth: true; text: content.controller.canCancelOperation ? "Esc: cancel operation" : "Enter: primary action   Left: close details   Esc: close"; color: Ui.Theme.mutedText; font.family: Ui.Theme.fontFamily; font.pixelSize: 10; wrapMode: Text.WordWrap }
            }
        }
    }

    BluetoothPairingPrompt { controller: content.controller }
}
