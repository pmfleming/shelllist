pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: actions

    required property ApplicationController controller
    required property var application
    required property real uiScale
    readonly property var desktopActions: application.desktop_actions || []

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)
    visible: desktopActions.length > 0

    Ui.SectionLabel {
        objectName: "applicationActionsHeading"
        text: qsTr("Application actions · %1").arg(actions.desktopActions.length)
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
                model: actions.desktopActions

                delegate: ColumnLayout {
                    id: actionRow
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        visible: actionRow.index > 0
                        color: Ui.Theme.border
                    }
                    Ui.LabeledAction {
                        objectName: "desktopAction-" + actionRow.modelData.id
                        Layout.fillWidth: true
                        Layout.leftMargin: Math.round(Ui.Theme.spacingLg * actions.uiScale)
                        Layout.rightMargin: Math.round(Ui.Theme.spacingSm * actions.uiScale)
                        Layout.topMargin: Math.round(Ui.Theme.spacingSm * actions.uiScale)
                        Layout.bottomMargin: Math.round(Ui.Theme.spacingSm * actions.uiScale)
                        uiScale: actions.uiScale
                        label: actionRow.modelData.name || qsTr("Application action")
                        // XDG icon names are opaque: resolve the supplied asset,
                        // never guess an action's meaning from its localized name.
                        iconSource: actionRow.modelData.icon ? Quickshell.iconPath(actionRow.modelData.icon, "") : ""
                        icon: Ui.MaterialIcons.name(actionRow.modelData.icon || "") || "open_in_new"
                        button.backgroundColor: "transparent"
                        button.borderColor: "transparent"
                        enabled: !actions.controller.operationBlocked && !actions.controller.operations.busy(actions.application.id)
                        onClicked: {
                            if (actions.controller.selectedApplication?.id !== actions.application.id)
                                return;
                            const action = actions.controller.detailActions.find(candidate => candidate.metadata?.desktopActionId === actionRow.modelData.id);
                            if (action && action.enabled !== false)
                                actions.controller.triggerDetailAction(action.id);
                        }
                    }
                }
            }
        }
    }
}
