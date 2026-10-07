pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// A window owns its presentation and command scope. The list owns shared column
// measurements; operation acknowledgement stays with ApplicationOperations.
ColumnLayout {
    id: instanceRow

    required property ApplicationController controller
    required property string applicationId
    required property string applicationName
    required property var modelData
    required property int index
    required property real uiScale
    required property real locationWidth
    required property string workspaceLabel
    required property font workspaceFont
    objectName: "windowRow-" + modelData.id
    readonly property string instanceTitle: modelData.title || applicationName || qsTr("Window")
    readonly property string workspaceDescription: qsTr("Workspace %1").arg(workspaceLabel === "?" ? qsTr("unknown") : workspaceLabel)
    readonly property string actionMessage: controller.operations.message(applicationId, modelData.id)
    readonly property bool focusSucceeded: controller.operations.focusSucceeded(applicationId, modelData.id)
    readonly property bool actionEnabled: !controller.operationBlocked && !controller.operations.busy(applicationId)
    Layout.fillWidth: true
    spacing: 0

    // Resolve the live action by stable window ID, not an index retained while
    // a menu was open across a catalog refresh. Never route to another app.
    function trigger(operation: string): void {
        if (controller.selectedApplication?.id !== applicationId)
            return;
        const action = controller.detailActions.find(candidate => candidate.metadata?.operation === operation && candidate.metadata?.windowId === modelData.id);
        if (action && action.enabled !== false)
            controller.triggerDetailAction(action.id);
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        visible: instanceRow.index > 0
        color: Ui.Theme.border
    }
    GridLayout {
        id: grid
        columns: 3
        Layout.fillWidth: true
        Layout.leftMargin: Math.round(Ui.Theme.spacingLg * instanceRow.uiScale)
        Layout.rightMargin: Math.round(Ui.Theme.spacingLg * instanceRow.uiScale)
        Layout.topMargin: Math.round(Ui.Theme.spacingMd * instanceRow.uiScale)
        Layout.bottomMargin: Math.round(Ui.Theme.spacingMd * instanceRow.uiScale)
        columnSpacing: Math.round(Ui.Theme.spacingSm * instanceRow.uiScale)
        rowSpacing: Math.round(Ui.Theme.spacingSm * instanceRow.uiScale)

        Item {
            Layout.preferredWidth: instanceRow.locationWidth
            implicitHeight: locationBadge.implicitHeight
            Rectangle {
                id: locationBadge
                width: Math.min(instanceRow.locationWidth, Math.max(Math.round(28 * instanceRow.uiScale), locationText.implicitWidth + Math.round(12 * instanceRow.uiScale)) + (currentIcon.visible ? currentIcon.width : 0))
                implicitHeight: Math.max(Math.round(28 * instanceRow.uiScale), locationText.implicitHeight + Math.round(8 * instanceRow.uiScale))
                height: implicitHeight
                radius: Math.round(8 * instanceRow.uiScale)
                color: instanceRow.modelData.focused ? Ui.Theme.selected : "transparent"
                border.color: instanceRow.modelData.focused ? Ui.Theme.accent : Ui.Theme.controlBorder
                Ui.ThemeText {
                    id: locationText
                    objectName: "windowLocation-" + instanceRow.modelData.id
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(6 * instanceRow.uiScale)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Math.round(12 * instanceRow.uiScale) - (currentIcon.visible ? currentIcon.width : 0)
                    text: instanceRow.workspaceLabel
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: instanceRow.modelData.focused ? Ui.Theme.selectedText : Ui.Theme.mutedText
                    font: instanceRow.workspaceFont
                    Accessible.role: Accessible.StaticText
                    Accessible.name: instanceRow.workspaceDescription
                }
                Ui.GlyphLabel {
                    id: currentIcon
                    objectName: "windowCurrent-" + instanceRow.modelData.id
                    visible: !!instanceRow.modelData.focused
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(28 * instanceRow.uiScale)
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    glyph: "center_focus_strong"
                    color: Ui.Theme.selectedText
                    font.pixelSize: Math.round(16 * instanceRow.uiScale)
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
                width: Math.max(0, Math.min(implicitWidth, titleGroup.width - (successIcon.visible ? successIcon.width + Ui.Theme.spacingSm * instanceRow.uiScale : 0)))
                anchors.verticalCenter: parent.verticalCenter
                text: instanceRow.instanceTitle
                wrapMode: Text.Wrap
                font.pixelSize: Math.round(Ui.Theme.fontSizeHeading * instanceRow.uiScale)
            }
            Ui.GlyphLabel {
                id: successIcon
                objectName: "windowFocusSuccess-" + instanceRow.modelData.id
                visible: instanceRow.focusSucceeded
                anchors.left: title.right
                anchors.leftMargin: Math.round(Ui.Theme.spacingSm * instanceRow.uiScale)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(18 * instanceRow.uiScale)
                glyph: "check"
                color: Ui.Theme.active
                font.pixelSize: Math.round(18 * instanceRow.uiScale)
                Accessible.role: Accessible.StaticText
                Accessible.name: instanceRow.actionMessage || qsTr("Window focused")
            }
        }

        Ui.SurfaceActionRow {
            objectName: "windowActions-" + instanceRow.modelData.id
            // Leave a readable title column where possible. Shared row sizing
            // owns gap/size reduction, disabled omission and enabled wrapping.
            Layout.preferredWidth: Math.min(2 * nominalControlHeight + gap,
                Math.max(minimumControlHeight, grid.width - instanceRow.locationWidth
                    - 2 * grid.columnSpacing - 6 * Ui.Theme.fontSizeHeading * instanceRow.uiScale))
            Layout.minimumWidth: minimumControlHeight
            Layout.preferredHeight: implicitHeight
            uiScale: instanceRow.uiScale
            compactSecondaryActions: true
            headerCommands: false
            actionObjectNamePrefix: ""
            actions: [
                {id: "focusWindow-" + instanceRow.modelData.id,
                    label: qsTr("Focus %1 on workspace %2").arg(instanceRow.instanceTitle).arg(instanceRow.workspaceLabel),
                    icon: "desktop_windows", enabled: instanceRow.actionEnabled,
                    presentation: {group: "toolbar"}},
                {id: "closeWindow-" + instanceRow.modelData.id,
                    label: qsTr("Close %1").arg(instanceRow.instanceTitle),
                    icon: "close", enabled: instanceRow.actionEnabled,
                    presentation: {group: "toolbar", tone: "danger"}}
            ]
            onTriggered: function(actionId) {
                if (actionId === "focusWindow-" + instanceRow.modelData.id)
                    instanceRow.trigger("focus-window");
                else if (actionId === "closeWindow-" + instanceRow.modelData.id)
                    instanceRow.trigger("close-window");
            }
        }
        Item {
            visible: actionStatus.visible
        }
        Ui.ThemeText {
            id: actionStatus
            objectName: "windowActionStatus-" + instanceRow.modelData.id
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: instanceRow.actionMessage.length > 0 && !instanceRow.focusSucceeded
            text: instanceRow.actionMessage
            wrapMode: Text.Wrap
            font.pixelSize: Math.round(Ui.Theme.fontSizeCaption * instanceRow.uiScale)
        }
    }
}
