pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: list

    required property ApplicationController controller
    required property var application
    required property real uiScale
    required property int actionHeight
    readonly property var instances: application.kind === "desktop-shortcut" ? [] : application.instances || []

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
                    readonly property string instanceTitle: modelData.title || list.application.name || qsTr("Window")
                    readonly property string workspaceLabel: String(modelData.workspace_name || modelData.workspace_id || qsTr("unknown"))
                    readonly property string actionMessage: list.controller.operations.message(list.application.id, modelData.id)
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
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Math.round(Ui.Theme.spacingLg * list.uiScale)
                        Layout.rightMargin: Math.round(Ui.Theme.spacingSm * list.uiScale)
                        Layout.topMargin: Math.round(Ui.Theme.spacingMd * list.uiScale)
                        Layout.bottomMargin: Math.round(Ui.Theme.spacingMd * list.uiScale)
                        spacing: Math.round(Ui.Theme.spacingSm * list.uiScale)

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: Ui.Theme.spacingXs
                            Ui.ThemeText {
                                objectName: "windowTitle-" + instanceRow.modelData.id
                                Layout.fillWidth: true
                                text: instanceRow.instanceTitle
                                wrapMode: Text.Wrap
                                font.pixelSize: Math.round(Ui.Theme.fontSizeHeading * list.uiScale)
                            }
                            Ui.ThemeText {
                                objectName: "windowLocation-" + instanceRow.modelData.id
                                Layout.fillWidth: true
                                text: qsTr("Workspace %1").arg(instanceRow.workspaceLabel)
                                color: Ui.Theme.mutedText
                                wrapMode: Text.Wrap
                                font.pixelSize: Ui.Theme.fontSizeSmall
                            }
                            Rectangle {
                                visible: !!instanceRow.modelData.focused
                                implicitWidth: currentLabel.implicitWidth + 12
                                implicitHeight: currentLabel.implicitHeight + 4
                                radius: 6
                                color: Ui.Theme.selected
                                Ui.ThemeText {
                                    id: currentLabel
                                    objectName: "windowCurrent-" + instanceRow.modelData.id
                                    anchors.centerIn: parent
                                    text: qsTr("Current window")
                                    color: Ui.Theme.selectedText
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

                        Ui.CommandGroup {
                            id: windowCommands
                            Layout.preferredWidth: focusButton.implicitWidth
                            Layout.preferredHeight: focusButton.implicitHeight
                            Ui.FlatIconButton {
                                id: focusButton
                                objectName: "focusWindow-" + instanceRow.modelData.id
                                sizeRole: "secondary"
                                uiScale: list.uiScale
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
                            uiScale: list.uiScale
                            icon: "more_horiz"
                            enabled: instanceRow.actionEnabled
                            accessibleName: qsTr("Commands for %1").arg(instanceRow.instanceTitle)
                            onClicked: if (shortcutNavigation) shortcutNavigation.openCommandMenuFor(windowCommands)
                        }
                    }
                }
            }
        }
    }
}
