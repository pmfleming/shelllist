pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: list
    objectName: "applicationInstanceList"

    required property ApplicationController controller
    required property var application
    required property real uiScale
    required property int actionHeight
    readonly property var instances: application.kind === "desktop-shortcut" ? [] : application.instances || []

    // Reserve the current-window marker even on non-current rows so titles align.
    readonly property real locationWidth: Math.min(Math.max(56 * uiScale,
        ...instances.map(window => workspaceMetrics.advanceWidth(workspaceLabel(window)) + 40 * uiScale)),
        Math.max(56 * uiScale, Math.min(120 * uiScale, width * 0.25)))

    function workspaceLabel(window: var): string {
        return String(window.workspace_name || window.workspace_id || "?");
    }

    FontMetrics {
        id: workspaceMetrics
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Math.round(Ui.Theme.fontSizeLabel * list.uiScale)
    }

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)
    visible: instances.length > 0

    Ui.SectionLabel {
        objectName: "applicationWindowsHeading"
        text: qsTr("Open windows · %1").arg(list.instances.length)
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: rows.implicitHeight
        radius: Ui.Theme.cardRadius
        color: Ui.Theme.surfaceContainer
        clip: true

        ColumnLayout {
            id: rows
            width: parent.width
            spacing: 0

            Repeater {
                model: list.instances

                delegate: ColumnLayout {
                    id: instanceRow
                    required property var modelData
                    required property int index
                    objectName: "windowRow-" + modelData.id
                    readonly property string instanceTitle: modelData.title || list.application.name || qsTr("Window")
                    readonly property string workspaceLabel: list.workspaceLabel(modelData)
                    readonly property string workspaceDescription: qsTr("Workspace %1").arg(workspaceLabel === "?" ? qsTr("unknown") : workspaceLabel)
                    readonly property string actionMessage: list.controller.operations.message(list.application.id, modelData.id)
                    readonly property bool focusSucceeded: list.controller.operations.focusSucceeded(list.application.id, modelData.id)
                    readonly property bool actionEnabled: !list.controller.operationBlocked && !list.controller.operations.busy(list.application.id)
                    Layout.fillWidth: true
                    spacing: 0

                    // Resolve the live action by stable window ID, not an index
                    // retained while a menu was open across a catalog refresh.
                    function trigger(operation: string): void {
                        if (list.controller.selectedApplication?.id !== list.application.id)
                            return;
                        const action = list.controller.detailActions.find(candidate => candidate.metadata?.operation === operation && candidate.metadata?.windowId === modelData.id);
                        if (action && action.enabled !== false)
                            list.controller.triggerDetailAction(action.id);
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        visible: instanceRow.index > 0
                        color: Ui.Theme.border
                    }
                    GridLayout {
                        columns: 4
                        Layout.fillWidth: true
                        Layout.leftMargin: Math.round(Ui.Theme.spacingLg * list.uiScale)
                        Layout.rightMargin: Math.round(Ui.Theme.spacingLg * list.uiScale)
                        Layout.topMargin: Math.round(Ui.Theme.spacingMd * list.uiScale)
                        Layout.bottomMargin: Math.round(Ui.Theme.spacingMd * list.uiScale)
                        columnSpacing: Math.round(Ui.Theme.spacingSm * list.uiScale)
                        rowSpacing: Math.round(Ui.Theme.spacingSm * list.uiScale)

                        Item {
                            Layout.preferredWidth: list.locationWidth
                            implicitHeight: locationBadge.implicitHeight
                            Rectangle {
                                id: locationBadge
                                width: Math.min(list.locationWidth, Math.max(Math.round(28 * list.uiScale), locationText.implicitWidth + Math.round(12 * list.uiScale)) + (currentIcon.visible ? currentIcon.width : 0))
                                implicitHeight: Math.max(Math.round(28 * list.uiScale), locationText.implicitHeight + Math.round(8 * list.uiScale))
                                height: implicitHeight
                                radius: Math.round(8 * list.uiScale)
                                color: instanceRow.modelData.focused ? Ui.Theme.selected : "transparent"
                                border.color: instanceRow.modelData.focused ? Ui.Theme.accent : Ui.Theme.controlBorder
                                Ui.ThemeText {
                                    id: locationText
                                    objectName: "windowLocation-" + instanceRow.modelData.id
                                    anchors.left: parent.left
                                    anchors.leftMargin: Math.round(6 * list.uiScale)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - Math.round(12 * list.uiScale) - (currentIcon.visible ? currentIcon.width : 0)
                                    text: instanceRow.workspaceLabel
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    color: instanceRow.modelData.focused ? Ui.Theme.selectedText : Ui.Theme.mutedText
                                    font: workspaceMetrics.font
                                    Accessible.role: Accessible.StaticText
                                    Accessible.name: instanceRow.workspaceDescription
                                }
                                Ui.GlyphLabel {
                                    id: currentIcon
                                    objectName: "windowCurrent-" + instanceRow.modelData.id
                                    visible: !!instanceRow.modelData.focused
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(28 * list.uiScale)
                                    height: parent.height
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    glyph: "center_focus_strong"
                                    color: Ui.Theme.selectedText
                                    font.pixelSize: Math.round(16 * list.uiScale)
                                    Accessible.role: Accessible.StaticText
                                    Accessible.name: qsTr("Current window")
                                    Rectangle {
                                        width: 1
                                        height: parent.height
                                        color: Ui.Theme.accent
                                    }
                                }
                            }
                        }
                        Item {
                            id: titleGroup
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            implicitHeight: Math.max(title.implicitHeight, successIcon.visible ? successIcon.implicitHeight : 0)
                            Ui.ThemeText {
                                id: title
                                objectName: "windowTitle-" + instanceRow.modelData.id
                                width: Math.max(0, Math.min(implicitWidth, titleGroup.width - (successIcon.visible ? successIcon.width + Ui.Theme.spacingSm * list.uiScale : 0)))
                                anchors.verticalCenter: parent.verticalCenter
                                text: instanceRow.instanceTitle
                                wrapMode: Text.Wrap
                                font.pixelSize: Math.round(Ui.Theme.fontSizeHeading * list.uiScale)
                            }
                            Ui.GlyphLabel {
                                id: successIcon
                                objectName: "windowFocusSuccess-" + instanceRow.modelData.id
                                visible: instanceRow.focusSucceeded
                                anchors.left: title.right
                                anchors.leftMargin: Math.round(Ui.Theme.spacingSm * list.uiScale)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(18 * list.uiScale)
                                glyph: "check"
                                color: Ui.Theme.active
                                font.pixelSize: Math.round(18 * list.uiScale)
                                Accessible.role: Accessible.StaticText
                                Accessible.name: instanceRow.actionMessage || qsTr("Window focused")
                            }
                        }

                        Ui.CommandGroup {
                            id: windowCommands
                            Layout.preferredWidth: focusButton.implicitWidth
                            Layout.preferredHeight: focusButton.implicitHeight
                            Ui.FlatIconButton {
                                id: focusButton
                                objectName: "focusWindow-" + instanceRow.modelData.id
                                sizeRole: "secondary"
                                uiScale: list.uiScale * 2 / 3
                                icon: "desktop_windows"
                                enabled: instanceRow.actionEnabled
                                accessibleName: qsTr("Focus %1 on workspace %2").arg(instanceRow.instanceTitle).arg(instanceRow.workspaceLabel)
                                onClicked: instanceRow.trigger("focus-window")
                            }
                            // Nonvisual command: accessible through the shared
                            // named menu, never a field or an adjacent × target.
                            Ui.ActionControl {
                                objectName: "closeWindow-" + instanceRow.modelData.id
                                width: 0
                                height: 0
                                activeFocusOnTab: false
                                Accessible.ignored: true
                                enabled: instanceRow.actionEnabled
                                accessibleName: qsTr("Close %1").arg(instanceRow.instanceTitle)
                                onClicked: instanceRow.trigger("close-window")
                            }
                        }
                        Ui.FlatIconButton {
                            objectName: "windowCommands-" + instanceRow.modelData.id
                            sizeRole: "secondary"
                            uiScale: list.uiScale * 2 / 3
                            icon: "more_horiz"
                            enabled: instanceRow.actionEnabled
                            accessibleName: qsTr("Commands for %1").arg(instanceRow.instanceTitle)
                            onClicked: if (shortcutNavigation) shortcutNavigation.openCommandMenuFor(windowCommands)
                        }
                        Item {
                            visible: actionStatus.visible
                        }
                        Ui.ThemeText {
                            id: actionStatus
                            objectName: "windowActionStatus-" + instanceRow.modelData.id
                            Layout.columnSpan: 3
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            visible: instanceRow.actionMessage.length > 0 && !instanceRow.focusSucceeded
                            text: instanceRow.actionMessage
                            wrapMode: Text.Wrap
                            font.pixelSize: Math.round(Ui.Theme.fontSizeCaption * list.uiScale)
                        }
                    }
                }
            }
        }
    }
}
