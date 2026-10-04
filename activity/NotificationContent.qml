pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content
    required property NotificationController controller
    chooserController: controller
    detailsTabEnabled: false

    listComponent: Ui.ChooserListPane {
        id: pane
        chooserController: content.controller
        resultModel: content.controller.notificationModel
        filterText: content.controller.filterText
        icon: ""
        placeholder: qsTr("Search loaded notifications…")
        powerVisible: false
        searchActionIcon: "󰒓"
        searchActionToolTip: qsTr("Notification settings")
        onSearchActionRequested: content.controller.openSettings()
        refreshing: content.controller.notificationState.historyLoading
        status: content.controller.notificationState.lastError || content.controller.notificationState.historyError || content.controller.screenshotStatus || (content.controller.notificationState.draftCount ? content.controller.notificationState.draftCount + qsTr(" unsent reply drafts") : "")
        emptyText: !content.controller.notificationState.notifications.available ? qsTr("Notifications unavailable") : refreshing && !content.controller.notificationState.historyLoaded ? qsTr("Loading notifications…") : filterText.length ? qsTr("No matching notifications") : qsTr("No notifications")
        emptyIcon: "󰂚"
        preserveViewportOnAppend: true
        readonly property bool loadMore: listNearEnd && !filterText.length && content.controller.notificationState.historyHasMore && !refreshing && !content.controller.notificationState.historyError
        onLoadMoreChanged: if (loadMore) Qt.callLater(content.controller.notificationState.loadMoreHistory)
        listOptionsComponent: Row {
            width: parent.width
            height: content.controller.returnSurface === "activity" ? Ui.Theme.controlHeight : 0
            spacing: Ui.Theme.spacingSm
            Ui.FlatIconButton {
                width: height
                height: parent.height
                visible: content.controller.returnSurface === "activity"
                icon: "󰁍"
                accessibleName: qsTr("Back to agenda")
                onClicked: content.controller.goBack()
            }
        }
        rowDelegate: Ui.ResultRow {
            id: row
            required property var resultData
            readonly property var notification: Ui.NotificationPresentation.notificationFor(JSON.parse(resultData.payload))
            listPane: pane
            rowHeight: pane.delegateHeight
            leadingIcon: "󰂚"
            accessibleName: (row.notification.app_name || qsTr("Notification")) + ". " + row.notification.summary
            Ui.ResultLabel {
                title: row.notification.summary || row.notification.app_name || qsTr("Notification")
                subtitle: [row.notification.app_name, Ui.NotificationPresentation.timeLabel(row.notification.created_unix_ms, content.controller.nowMs), row.notification.body].filter(part => !!part).join(" · ")
            }
        }
    }
    detailsComponent: Ui.DetailFlickable {
        viewMemory: content.controller.viewMemory
        memoryTab: content.controller.settingsOpen ? "settings" : "message"
        NotificationSettings {
            visible: content.controller.settingsOpen
            notificationState: content.controller.notificationState
        }
        NotificationHistoryRow {
            width: parent.width
            visible: !content.controller.settingsOpen && content.controller.hasSelection
            controller: content.controller
            record: content.controller.selectedRecord || ({})
        }
    }
}
