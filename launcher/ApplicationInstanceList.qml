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
        text: qsTr("Running instances")
    }

    Repeater {
        model: list.instances

        delegate: Rectangle {
            id: instanceRow
            required property var modelData
            required property int index
            readonly property string instanceTitle: modelData.title || list.application.name || "Window"
            readonly property string workspaceLabel: modelData.workspace_name || modelData.workspace_id || "unknown"
            readonly property string actionMessage: list.controller.operations.message(list.application.id, modelData.id)
            readonly property bool actionEnabled: !list.controller.operationBlocked && !list.controller.operations.busy(list.application.id)
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Math.round(50 * list.uiScale), rowContent.implicitHeight + 16)
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.surface
            border.color: modelData.focused ? Ui.Theme.accent : Ui.Theme.border
            border.width: 1

            RowLayout {
                id: rowContent
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        text: instanceRow.instanceTitle
                        elide: Text.ElideRight
                        font.pixelSize: Ui.Theme.fontSizeLabel
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Ui.ThemeText {
                            Layout.fillWidth: true
                            text: "Workspace " + instanceRow.workspaceLabel
                            color: instanceRow.modelData.focused ? Ui.Theme.active : Ui.Theme.mutedText
                            elide: Text.ElideRight
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                        Ui.ThemeText {
                            text: Presentation.usageText(instanceRow.modelData)
                            color: Ui.Theme.mutedText
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                    }
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        visible: instanceRow.actionMessage.length > 0
                        text: instanceRow.actionMessage
                        wrapMode: Text.Wrap
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                }

                Ui.FlatIconButton {
                    Layout.preferredWidth: list.actionHeight
                    Layout.preferredHeight: list.actionHeight
                    icon: Presentation.runningWindowIcon(1)
                    flatIconColor: instanceRow.modelData.focused ? Ui.Theme.active : Ui.Theme.accent
                    objectName: "focusWindow-" + instanceRow.modelData.id
                    enabled: instanceRow.actionEnabled
                    accessibleName: "Focus " + instanceRow.instanceTitle
                    toolTip: "Focus “" + instanceRow.instanceTitle + "” on workspace " + instanceRow.workspaceLabel
                    onClicked: list.controller.triggerDetailAction("focus-window-" + instanceRow.index)
                }

                Ui.DestructiveIconButton {
                    Layout.preferredWidth: list.actionHeight
                    Layout.preferredHeight: list.actionHeight
                    objectName: "closeWindow-" + instanceRow.modelData.id
                    enabled: instanceRow.actionEnabled
                    accessibleName: "Close " + instanceRow.instanceTitle
                    toolTip: "Close “" + instanceRow.instanceTitle + "”"
                    onClicked: list.controller.triggerDetailAction("close-window-" + instanceRow.index)
                }
            }
        }
    }
}
