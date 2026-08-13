pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation

ColumnLayout {
    id: list

    required property ApplicationController controller
    required property var application
    required property real uiScale
    required property int actionHeight
    readonly property var instances: application.instances || []

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)

    Ui.SectionLabel {
        visible: list.instances.length > 0
        text: "Running instances"
    }

    Repeater {
        model: list.instances

        delegate: Rectangle {
            id: instanceRow
            required property var modelData
            required property int index
            readonly property string instanceTitle: modelData.title || list.application.name || "Window"
            readonly property string workspaceLabel: modelData.workspace_name || modelData.workspace_id || "unknown"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(50 * list.uiScale)
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.surface
            border.color: modelData.focused ? Ui.Theme.accent : Ui.Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: instanceRow.instanceTitle
                        color: Ui.Theme.text
                        elide: Text.ElideRight
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeLabel
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            Layout.fillWidth: true
                            text: "Workspace " + instanceRow.workspaceLabel
                            color: instanceRow.modelData.focused ? Ui.Theme.active : Ui.Theme.mutedText
                            elide: Text.ElideRight
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                        Text {
                            text: Presentation.usageText(instanceRow.modelData)
                            color: Ui.Theme.mutedText
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                    }
                }

                Ui.ActionButton {
                    Layout.preferredWidth: list.actionHeight
                    Layout.preferredHeight: list.actionHeight
                    label: ""
                    icon: "󰖯"
                    tone: instanceRow.modelData.focused ? "active" : "normal"
                    enabled: !list.controller.actionInFlight
                    accessibleName: "Focus " + instanceRow.instanceTitle
                    toolTip: "Focus “" + instanceRow.instanceTitle + "” on workspace " + instanceRow.workspaceLabel
                    onClicked: list.controller.triggerDetailAction("focus-window-" + instanceRow.index)
                }

                Ui.ActionButton {
                    Layout.preferredWidth: list.actionHeight
                    Layout.preferredHeight: list.actionHeight
                    label: ""
                    icon: "󰅖"
                    tone: "danger"
                    enabled: !list.controller.actionInFlight
                    accessibleName: "Close " + instanceRow.instanceTitle
                    toolTip: "Close “" + instanceRow.instanceTitle + "”"
                    onClicked: list.controller.triggerDetailAction("close-window-" + instanceRow.index)
                }
            }
        }
    }
}
