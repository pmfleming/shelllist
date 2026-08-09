pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

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
    }

    Ui.ActionToolbar {
        width: parent.width
        height: pane.toolbarHeight
        actions: pane.actions
        group: "primary"
        alignRight: false
        controlHeight: pane.toolbarHeight
        onTriggered: function (actionId) { pane.controller.triggerDetailAction(actionId); }
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
        height: Math.max(0, parent.height - pane.headerHeight - 2 * pane.toolbarHeight - 3 * pane.sectionSpacing)
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
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(50 * pane.uiScale)
                    radius: Ui.Theme.cardRadius
                    color: instanceMouse.containsMouse ? Ui.Theme.hover : Ui.Theme.surface
                    border.color: modelData.focused ? Ui.Theme.accent : Ui.Theme.border
                    border.width: 1

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 2
                        Text {
                            width: parent.width
                            text: instanceRow.modelData.title || pane.application.name || "Window"
                            color: Ui.Theme.text
                            elide: Text.ElideRight
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeLabel
                        }
                        Text {
                            width: parent.width
                            text: (instanceRow.modelData.focused ? "Active · " : "") + "Workspace " + (instanceRow.modelData.workspace_name || instanceRow.modelData.workspace_id || "unknown")
                            color: instanceRow.modelData.focused ? Ui.Theme.active : Ui.Theme.mutedText
                            elide: Text.ElideRight
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                    }
                    MouseArea {
                        id: instanceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.controller.triggerDetailAction("focus-window-" + instanceRow.index)
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
