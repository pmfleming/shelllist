pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation

Ui.DetailsPane {
    id: pane

    required property ApplicationController controller
    required property real uiScale
    readonly property var selected: controller.selectedResult || ({})
    readonly property var application: controller.selectedApplication || ({})
    readonly property var actions: controller.detailActions || []
    readonly property int headerHeight: Math.max(58, Math.round(66 * uiScale))
    readonly property int toolbarHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))

    chooserController: controller
    densityScale: uiScale
    leftMargin: 18
    rightMargin: 16
    emptyText: "Select an application"

    Ui.DetailsHeader {
        width: parent.width
        height: pane.headerHeight
        uiScale: pane.uiScale
        icon: "󰀻"
        iconColor: pane.application.focused ? Ui.Theme.active : Ui.Theme.accent
        title: pane.selected.title || "Application"
        subtitle: pane.selected.subtitle || ""
        titlePixelSize: Math.round(Ui.Theme.fontSizeTitle * pane.uiScale)
        actions: pane.actions
        actionWidth: 128
        controlHeight: pane.toolbarHeight
        onActionTriggered: function (actionId) { pane.controller.triggerDetailAction(actionId); }
    }

    Ui.ActionToolbar {
        width: parent.width
        height: pane.toolbarHeight
        actions: pane.actions
        group: "toolbar"
        alignRight: true
        controlHeight: pane.toolbarHeight
        onTriggered: function (actionId) { pane.controller.triggerDetailAction(actionId); }
    }

    Flickable {
        width: parent.width
        height: Math.max(0, parent.height - pane.headerHeight - pane.toolbarHeight - 2 * pane.sectionSpacing)
        contentWidth: width
        contentHeight: detailColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: detailColumn
            width: parent.width
            spacing: Math.round(Ui.Theme.spacingMd * pane.uiScale)

            Text {
                visible: pane.application.comment && pane.application.comment.length > 0
                Layout.fillWidth: true
                text: pane.application.comment || ""
                color: Ui.Theme.mutedText
                wrapMode: Text.Wrap
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeBody
            }

            Text {
                visible: pane.application.running
                Layout.fillWidth: true
                text: "Total usage · " + Presentation.usageText(pane.application)
                color: Ui.Theme.accent
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeLabel
                font.weight: Ui.Theme.fontWeightDemiBold
            }

            Text {
                visible: (pane.application.instances || []).length > 0
                Layout.fillWidth: true
                text: "Running instances"
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeLabel
                font.weight: Ui.Theme.fontWeightDemiBold
            }

            Repeater {
                model: pane.application.instances || []

                delegate: Rectangle {
                    id: instanceRow
                    required property var modelData
                    required property int index
                    readonly property string instanceTitle: modelData.title || pane.application.name || "Window"
                    readonly property string workspaceLabel: modelData.workspace_name || modelData.workspace_id || "unknown"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(50 * pane.uiScale)
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
                            Layout.preferredWidth: pane.toolbarHeight
                            Layout.preferredHeight: pane.toolbarHeight
                            label: ""
                            icon: "󰖯"
                            hotkey: ""
                            tone: instanceRow.modelData.focused ? "active" : "normal"
                            enabled: !pane.controller.actionInFlight
                            accessibleName: "Focus " + instanceRow.instanceTitle
                            toolTip: "Focus “" + instanceRow.instanceTitle + "” on workspace "
                                + instanceRow.workspaceLabel
                            onClicked: pane.controller.triggerDetailAction("focus-window-" + instanceRow.index)
                        }

                        Ui.ActionButton {
                            Layout.preferredWidth: pane.toolbarHeight
                            Layout.preferredHeight: pane.toolbarHeight
                            label: ""
                            icon: "󰅖"
                            hotkey: ""
                            tone: "danger"
                            enabled: !pane.controller.actionInFlight
                            accessibleName: "Close " + instanceRow.instanceTitle
                            toolTip: "Close “" + instanceRow.instanceTitle + "”"
                            onClicked: pane.controller.triggerDetailAction("close-window-" + instanceRow.index)
                        }
                    }
                }
            }

            Text {
                visible: (pane.application.desktop_actions || []).length > 0
                Layout.fillWidth: true
                text: "Application actions"
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeLabel
                font.weight: Ui.Theme.fontWeightDemiBold
            }

            Repeater {
                model: pane.application.desktop_actions || []

                delegate: Rectangle {
                    id: desktopActionRow
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(42 * pane.uiScale)
                    radius: Ui.Theme.cardRadius
                    color: desktopActionMouse.containsMouse ? Ui.Theme.hover : Ui.Theme.surface
                    border.color: Ui.Theme.border
                    border.width: 1

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        text: desktopActionRow.modelData.name || "Application action"
                        color: Ui.Theme.text
                        elide: Text.ElideRight
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeLabel
                    }
                    MouseArea {
                        id: desktopActionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.controller.triggerDetailAction("desktop-action-" + desktopActionRow.index)
                    }
                }
            }

            Ui.CenteredMessage {
                visible: (pane.application.instances || []).length === 0 && (pane.application.desktop_actions || []).length === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                text: pane.application.kind === "desktop-application" ? "No additional actions" : "Window is no longer available"
                font.pixelSize: Ui.Theme.fontSizeBody
            }
        }
    }
}
