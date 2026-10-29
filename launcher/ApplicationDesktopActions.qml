pragma ComponentBehavior: Bound

import Quickshell as Qs
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import Shelllist.Core as Core

ColumnLayout {
    id: actions

    required property ApplicationController controller
    required property var application
    required property real uiScale
    readonly property var desktopActions: application.desktop_actions || []
    signal pageChanged(Item anchor)

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)
    visible: desktopActions.length > 0

    Ui.DetailColumnCard {
        objectName: "applicationActionsCard"
        title: actions.desktopActions.length > pager.pageSize ? "" : qsTr("Application actions · %1").arg(actions.desktopActions.length)
        Layout.fillWidth: true
        contentSpacing: 0
        color: Ui.Theme.surfaceContainer
        clip: true

        Ui.CollectionPager {
            id: pager
            objectName: "applicationActionPages"
            title: qsTr("Application actions")
            visible: actions.desktopActions.length > pageSize
            items: actions.desktopActions
            contextKey: actions.application.id || ""
            viewMemory: actions.controller.viewMemory
            memoryTab: "application"
            memoryKey: "actions"
            blocked: actions.controller.operationBlocked || actions.controller.operations.busy(actions.application.id)
            onPageRequested: function(offset) {
                if (blocked) return;
                actions.controller.detailsClosing();
                pager.showPage(offset);
                actions.pageChanged(pager);
            }
        }
        Core.KeyedListModel {
            id: actionRows
            values: pager.visibleItems.map(action => ({key: actions.application.id + ":" + action.id,
                applicationId: actions.application.id, payload: action}))
        }
        Repeater {
            model: actionRows

            delegate: ColumnLayout {
                id: actionRow
                required property var resultData
                readonly property var modelData: resultData.payload
                readonly property string applicationId: resultData.applicationId
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
                    Layout.topMargin: Math.round(Ui.Theme.spacingSm * actions.uiScale)
                    Layout.bottomMargin: Math.round(Ui.Theme.spacingSm * actions.uiScale)
                    uiScale: actions.uiScale
                    label: actionRow.modelData.name || qsTr("Application action")
                    // XDG icon names are opaque: resolve the supplied asset,
                    // never guess an action's meaning from its localized name.
                    iconSource: actionRow.modelData.icon ? Qs.Quickshell.iconPath(actionRow.modelData.icon, "") : ""
                    icon: Ui.MaterialIcons.name(actionRow.modelData.icon || "") || "open_in_new"
                    button.backgroundColor: "transparent"
                    button.borderColor: "transparent"
                    enabled: !actions.controller.operationBlocked && !actions.controller.operations.busy(actionRow.applicationId)
                    onClicked: {
                        if (actions.controller.selectedApplication?.id !== actionRow.applicationId)
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
