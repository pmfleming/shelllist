pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: prompt

    required property string heading
    required property string detail
    property string rejectLabel: "Reject"
    property string acceptLabel: "Confirm"
    property string footer: ""
    property bool actionsVisible: true
    property bool acceptEnabled: true
    default property alias body: bodyColumn.data

    signal accepted
    signal rejected

    anchors.fill: parent
    radius: Ui.Theme.windowRadius
    color: Ui.Theme.mix(Ui.Theme.window, "#000000", 0.12)
    border.color: Ui.Theme.strongBorder

    Shortcut { sequence: "Escape"; enabled: prompt.visible && prompt.actionsVisible; onActivated: prompt.rejected() }
    Shortcut { sequence: "Enter"; enabled: prompt.visible && prompt.actionsVisible && prompt.acceptEnabled; onActivated: prompt.accepted() }
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
                text: prompt.heading
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                Layout.fillWidth: true
                text: prompt.detail
                color: Ui.Theme.subtleText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            ColumnLayout {
                id: bodyColumn
                Layout.fillWidth: true
                spacing: 13
            }
            RowLayout {
                visible: prompt.actionsVisible
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: [
                        { label: prompt.rejectLabel, accept: false },
                        { label: prompt.acceptLabel, accept: true }
                    ]
                    delegate: Rectangle {
                        id: button
                        required property var modelData
                        readonly property bool available: !modelData.accept || prompt.acceptEnabled
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Ui.Theme.cardRadius
                        color: modelData.accept ? Ui.Theme.accent : Ui.Theme.surfaceRaised
                        border.color: modelData.accept ? Ui.Theme.accent : Ui.Theme.border
                        opacity: available ? 1 : 0.45
                        Text {
                            anchors.centerIn: parent
                            text: button.modelData.label
                            color: button.modelData.accept ? Ui.Theme.window : Ui.Theme.subtleText
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: button.available
                            cursorShape: Qt.PointingHandCursor
                            onClicked: button.modelData.accept ? prompt.accepted() : prompt.rejected()
                        }
                    }
                }
            }
            Text {
                visible: prompt.footer.length > 0
                Layout.fillWidth: true
                text: prompt.footer
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
