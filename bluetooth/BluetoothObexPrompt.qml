import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: prompt

    required property var controller
    readonly property var request: controller.incomingTransferPrompt || ({})

    anchors.fill: parent
    visible: controller.incomingTransferPromptOpen
    z: 110
    radius: Ui.Theme.windowRadius
    color: Ui.Theme.mix(Ui.Theme.window, "#000000", 0.12)
    border.color: Ui.Theme.strongBorder

    function sizeLabel() {
        const size = Number(request.size || 0);
        if (size <= 0) return "Size unavailable";
        if (size < 1024) return size + " B";
        if (size < 1024 * 1024) return (size / 1024).toFixed(1) + " KiB";
        if (size < 1024 * 1024 * 1024) return (size / (1024 * 1024)).toFixed(1) + " MiB";
        return (size / (1024 * 1024 * 1024)).toFixed(1) + " GiB";
    }

    Shortcut { sequence: "Escape"; enabled: prompt.visible; onActivated: prompt.controller.respondIncomingTransfer(false) }
    Shortcut { sequence: "Enter"; enabled: prompt.visible; onActivated: prompt.controller.respondIncomingTransfer(true) }

    MouseArea { anchors.fill: parent }

    Rectangle {
        anchors.centerIn: parent
        width: 430
        implicitHeight: promptColumn.implicitHeight + 48
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.strongBorder

        ColumnLayout {
            id: promptColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 24
            spacing: 13

            Text {
                Layout.fillWidth: true
                text: "Accept Bluetooth file?"
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                Layout.fillWidth: true
                text: (prompt.request.device_name || "A paired Bluetooth device") + " wants to send:"
                color: Ui.Theme.subtleText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                Layout.fillWidth: true
                text: prompt.request.file_name || "Unnamed file"
                color: Ui.Theme.accent
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 17
                font.bold: true
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                Layout.fillWidth: true
                text: prompt.sizeLabel() + (prompt.request.media_type ? " · " + prompt.request.media_type : "") + "\nAccepted files are saved in Downloads."
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Ui.Theme.cardRadius
                    color: Ui.Theme.surfaceRaised
                    border.color: Ui.Theme.border
                    Text { anchors.centerIn: parent; text: "Reject"; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 13; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: prompt.controller.respondIncomingTransfer(false) }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Ui.Theme.cardRadius
                    color: Ui.Theme.accent
                    Text { anchors.centerIn: parent; text: "Accept"; color: Ui.Theme.window; font.family: Ui.Theme.fontFamily; font.pixelSize: 13; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: prompt.controller.respondIncomingTransfer(true) }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "Enter: accept   Esc: reject"
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
