pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content
    required property NotificationController controller
    chooserController: controller
    keyboardWorkflow: true
    detailsTabEnabled: false

    listComponent: Ui.ChooserListPane {
        id: pane
        chooserController: content.controller
        resultModel: content.controller.groupModel
        filterText: content.controller.filterText
        icon: ""
        placeholder: content.controller.tab === "history" ? qsTr("Search loaded history…") : qsTr("Search notifications…")
        powered: content.controller.notificationState.notifications.dnd
        powerEnabled: content.controller.notificationState.notifications.available
        powerAccessory: NotificationDndDuration { notificationState: content.controller.notificationState }
        refreshing: content.controller.notificationState.historyLoading
        status: content.controller.notificationState.lastError || (content.controller.tab === "history" ? content.controller.notificationState.historyError : "") || content.controller.screenshotStatus || (content.controller.notificationState.draftCount ? content.controller.notificationState.draftCount + qsTr(" unsent reply drafts") : "")
        emptyText: qsTr("No notifications")
        emptyIcon: "󰂚"
        preserveViewportOnAppend: true
        readonly property bool loadMore: listNearEnd && content.controller.tab === "history" && content.controller.notificationState.historyHasMore && !refreshing && !content.controller.notificationState.historyError
        onLoadMoreChanged: if (loadMore) Qt.callLater(content.controller.notificationState.loadMoreHistory)
        listOptionsComponent: Row {
            width: parent.width
            height: Ui.Theme.controlHeight
            spacing: Ui.Theme.spacingSm
            Ui.FlatIconButton {
                width: height
                height: parent.height
                visible: content.controller.returnSurface === "activity"
                icon: "󰁍"
                accessibleName: qsTr("Back to agenda")
                onClicked: content.controller.goBack()
            }
            Ui.SegmentedControl {
                objectName: "notificationTabs"
                width: 240
                value: content.controller.tab
                options: [{value: "active", label: qsTr("Active")}, {value: "history", label: qsTr("History")}]
                onSelected: function (value) { content.controller.tab = value; }
            }
            Ui.FlatIconButton {
                objectName: "notificationClearAll"
                width: height
                height: parent.height
                icon: "󰎟"
                accessibleName: qsTr("Dismiss all active notifications")
                enabled: content.controller.notificationState.activeNotifications.length > 0
                onClicked: content.controller.notificationState.clearNotifications()
            }
        }
        rowDelegate: Ui.ResultRow {
            id: row
            required property var resultData
            readonly property var group: JSON.parse(resultData.payload)
            listPane: pane
            rowHeight: pane.delegateHeight
            leadingIcon: "󰂚"
            accessibleName: (row.group.appName || qsTr("Notifications")) + ". " + row.group.records.length
            Ui.ResultLabel {
                title: row.group.appName || qsTr("Notifications")
                subtitle: String(row.group.records.length)
            }
        }
    }
    detailsComponent: Ui.DetailFlickable {
        viewMemory: content.controller.viewMemory
        memoryTab: "messages"
        NotificationHistoryGroup {
            width: parent.width
            controller: content.controller
            group: content.controller.selectedGroup || {key: "", records: [], appName: ""}
        }
    }
    Shortcut {
        sequences: ["Ctrl+Tab", "Ctrl+Shift+Tab"]
        enabled: content.controller.uiActive && !content.detailsNavigation.popupOpen
        onActivated: {
            content.controller.navigationInteracted();
            content.controller.tab = content.controller.tab === "active" ? "history" : "active";
        }
    }
}
