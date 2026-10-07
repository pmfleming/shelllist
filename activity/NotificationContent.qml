pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content
    required property NotificationController controller
    chooserController: controller
    detailsTabEnabled: controller.detailsOpen && controller.hasSelection && !controller.settingsOpen
    // No command host in the collapsed list. Only the active detail page
    // participates in shared command discovery.
    Binding {
        target: content.controller
        property: "replyEditorFocused"
        value: content.detailsNavigation.activeFocus && content.detailsNavigation.currentTarget?.objectName === "notificationReplyInput"
    }
    Connections {
        target: content.controller
        function onSelectedKeyChanged(): void { content.detailsNavigation.closeCommandMenu(); }
        function onSelectedAppKeyChanged(): void { content.detailsNavigation.closeCommandMenu(); }
        function onDetailsTabChanged(): void { content.detailsNavigation.closeCommandMenu(); }
        function onSettingsOpenChanged(): void { content.detailsNavigation.closeCommandMenu(); }
        function onSelectedLiveChanged(): void { if (!content.controller.selectedLive) content.detailsNavigation.closeCommandMenu(); }
    }
    Connections {
        target: content.controller.catalog
        function onDetailChanged(): void { content.detailsNavigation.closeCommandMenu(); }
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
        refreshing: content.controller.catalog.rootBusy
        status: content.controller.notificationState.lastError || content.controller.catalog.rootError || content.controller.screenshotStatus || content.controller.copyStatus || (content.controller.notificationState.draftCount ? content.controller.notificationState.draftCount + qsTr(" unsent reply drafts") : "")
        emptyState: content.controller.catalog.rootError ? "unavailable" : refreshing ? "loading" : !content.controller.notificationState.notifications.available ? "unavailable" : filterText.trim() ? "filtered" : "empty"
        emptyText: content.controller.catalog.rootError || (emptyState === "loading" ? qsTr("Loading notifications…") : emptyState === "unavailable" ? qsTr("Notifications unavailable") : emptyState === "filtered" ? qsTr("No matching notifications") : qsTr("No notifications"))
        emptyIcon: "notifications_none"
        preserveViewportOnAppend: true
        readonly property bool loadMore: listNearEnd && content.controller.catalog.hasMore && !refreshing && !content.controller.catalog.rootError
        onLoadMoreChanged: if (loadMore) Qt.callLater(content.controller.catalog.loadMore)
        listOptionsComponent: Ui.FlatIconButton {
            width: height
            height: visible ? Ui.Theme.controlHeight : 0
            visible: content.controller.returnSurface === "activity"
            icon: "󰁍"
            accessibleName: qsTr("Back to agenda")
            onClicked: content.controller.goBack()
        }
        rowDelegate: Ui.ResultRow {
            id: row
            required property var resultData
            readonly property var app: JSON.parse(resultData.payload)
            listPane: pane
            rowHeight: pane.delegateHeight
            leadingIcon: "󰂚"
            leadingIconSource: identity.source
            accessibleName: (app.latest.app_name || qsTr("Notification")) + qsTr(" · %1 matching of %2 recent notifications · ").arg(app.count).arg(app.total_count) + app.latest.summary
            Ui.NotificationAppIcon { id: identity; visible: false; notification: row.app.latest }
            Ui.ResultLabel {
                title: (row.app.latest.app_name || qsTr("Notification")) + " · " + row.app.count
                subtitle: [Ui.NotificationPresentation.timeLabel(row.app.latest.created_unix_ms, content.controller.nowMs), row.app.latest.summary, row.app.latest.body.replace(/\s+/g, " ")].filter(Boolean).join(" · ")
            }
        }
    }
    detailsComponent: NotificationDetails {
        controller: content.controller
        navigation: content.detailsNavigation
    }
}
