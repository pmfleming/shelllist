pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content
    required property NotificationController controller
    chooserController: controller
    detailsTabEnabled: false
    property Item messageCommands: null
    property Item messageHeaderHost: null
    additionalCommandItem: messageCommands
    commandsWithoutDetails: controller.hasSelection && !controller.settingsOpen
    Binding {
        target: content.controller
        property: "replyEditorFocused"
        value: content.detailsNavigation.activeFocus && content.detailsNavigation.currentTarget?.objectName === "notificationReplyInput"
    }
    Connections {
        target: content.controller
        function onSelectedKeyChanged(): void { content.detailsNavigation.closeCommandMenu(); }
        function onSettingsOpenChanged(): void { content.detailsNavigation.closeCommandMenu(); }
        function onSelectedLiveChanged(): void { if (!content.controller.selectedLive) content.detailsNavigation.closeCommandMenu(); }
    }

    listComponent: Ui.ChooserListPane {
        id: pane
        chooserController: content.controller
        resultModel: content.controller.notificationModel
        filterText: content.controller.filterText
        icon: ""
        placeholder: qsTr("Search recent notifications…")
        powerVisible: false
        searchActionIcon: "󰒓"
        searchActionToolTip: qsTr("Notification settings")
        onSearchActionRequested: content.controller.openSettings()
        refreshing: content.controller.notificationState.historyLoading
        status: content.controller.notificationState.lastError || content.controller.notificationState.historyError || content.controller.screenshotStatus || content.controller.copyStatus || (content.controller.notificationState.draftCount ? content.controller.notificationState.draftCount + qsTr(" unsent reply drafts") : "")
        emptyState: content.controller.notificationState.historyError ? "unavailable" : refreshing ? "loading" : !content.controller.notificationState.notifications.available ? "unavailable" : filterText.trim() ? "filtered" : "empty"
        emptyText: content.controller.notificationState.historyError || (emptyState === "loading" ? qsTr("Loading notifications…") : emptyState === "unavailable" ? qsTr("Notifications unavailable") : content.controller.notificationState.historyQuery !== filterText ? qsTr("Waiting for search…") : emptyState === "filtered" ? qsTr("No matching notifications") : qsTr("No notifications"))
        emptyIcon: "notifications_none"
        preserveViewportOnAppend: true
        readonly property bool loadMore: listNearEnd && content.controller.notificationState.historyHasMore && !refreshing && !content.controller.notificationState.historyError
        onLoadMoreChanged: if (loadMore) Qt.callLater(content.controller.notificationState.loadMoreHistory)
        listOptionsComponent: Column {
            id: listOptions
            width: parent.width
            spacing: Ui.Theme.spacingSm
            Ui.FlatIconButton {
                width: height
                height: Ui.Theme.controlHeight
                visible: content.controller.returnSurface === "activity"
                icon: "󰁍"
                accessibleName: qsTr("Back to agenda")
                onClicked: content.controller.goBack()
            }
            NotificationCommands {
                id: commands
                controller: content.controller
                navigation: content.detailsNavigation
                listHost: listOptions
                detailHost: content.messageHeaderHost
                Component.onCompleted: content.messageCommands = commands
                Component.onDestruction: if (content && content.messageCommands === commands) content.messageCommands = null
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
            commandItem: content.messageCommands
            Component.onCompleted: content.messageHeaderHost = headerHost
            Component.onDestruction: if (content) content.messageHeaderHost = null
            visible: !content.controller.settingsOpen && content.controller.hasSelection
            controller: content.controller
            record: content.controller.selectedRecord || ({})
        }
    }
}
