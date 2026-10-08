pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content
    required property NotificationController controller
    chooserController: controller
    navigationEnabled: !controller.notificationState.deleteConfirmation
    detailsTabEnabled: navigationEnabled && controller.detailsOpen && controller.hasSelection && !controller.settingsOpen
    commandsWithoutDetails: controller.hasSelection && !controller.settingsOpen
    additionalCommandItem: collapsedCommands
    Ui.CommandGroup {
        id: collapsedCommands
        visible: content.commandsWithoutDetails && !content.controller.detailsOpen
        enabled: visible
        Repeater {
            model: content.controller.appCommands
            Ui.ActionControl {
                required property var modelData
                accessibleName: modelData.label
                accessKey: modelData.accessKey
                enabled: collapsedCommands.enabled && modelData.enabled
                onClicked: content.controller.triggerAppAction(modelData.id, content.controller.selectedAppKey)
            }
        }
    }
    Connections {
        target: content.controller
        function onSelectedAppKeyChanged(): void { content.detailsNavigation.closeCommandMenu(); }
        function onDetailsTabChanged(): void { content.detailsNavigation.closeCommandMenu(); }
        function onSettingsOpenChanged(): void { content.detailsNavigation.closeCommandMenu(); }
    }
    Connections {
        target: content.controller.timeline
        function onEntriesChanged(): void { content.detailsNavigation.closeCommandMenu(); }
        function onSnapshotChanged(): void { content.detailsNavigation.closeCommandMenu(); }
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
        status: content.controller.notificationState.lastError || content.controller.catalog.rootError || content.controller.screenshotStatus
        emptyState: content.controller.catalog.rootError ? "unavailable" : refreshing ? "loading" : !content.controller.notificationState.notifications.available ? "unavailable" : filterText.trim() ? "filtered" : "empty"
        emptyText: content.controller.catalog.rootError || (emptyState === "loading" ? qsTr("Loading notifications…") : emptyState === "unavailable" ? qsTr("Notifications unavailable") : emptyState === "filtered" ? qsTr("No matching notifications") : qsTr("No notifications"))
        emptyIcon: "notifications_none"
        preserveViewportOnAppend: true
        readonly property bool loadMore: listNearEnd && content.controller.catalog.hasMore && !refreshing && !content.controller.catalog.rootError
        onLoadMoreChanged: if (loadMore) Qt.callLater(content.controller.catalog.loadMore)
        // Do not instantiate a hidden button: the shared options loader uses
        // implicitHeight, so an invisible control still reserves a whole row.
        listOptionsComponent: content.controller.returnSurface === "activity" ? backToAgenda : null
        Component {
            id: backToAgenda
            Ui.FlatIconButton {
                objectName: "notificationsBackToAgenda"
                width: height
                height: Ui.Theme.controlHeight
                icon: "󰁍"
                accessibleName: qsTr("Back to agenda")
                onClicked: content.controller.goBack()
            }
        }
        rowDelegate: Ui.ResultRow {
            id: row
            required property var resultData
            readonly property var app: JSON.parse(resultData.payload)
            readonly property string latestText: [Ui.NotificationPresentation.previewHeading(app.latest), Ui.NotificationPresentation.previewBody(app.latest)].filter(Boolean).join(" · ") || qsTr("Notification")
            readonly property string metadata: [Ui.NotificationPresentation.timeLabel(app.latest.created_unix_ms, content.controller.nowMs), app.latest.app_name || qsTr("Unknown app"), qsTr("%1 notifications").arg(app.total_count), content.controller.notificationState.appPolicy(app.key).silent ? qsTr("Silent") : ""].filter(Boolean).join(" · ")
            objectName: "notificationAppRow-" + app.key
            listPane: pane
            rowHeight: pane.delegateHeight
            leadingIcon: Ui.NotificationIconSource.fallback(row.app.latest)
            leadingIconSource: Ui.NotificationIconSource.resolve(row.app.latest)
            accessibleName: latestText + " · " + metadata + (app.count !== app.total_count ? qsTr(" · %1 matching").arg(app.count) : "")
            Ui.ResultLabel {
                objectName: "notificationAppLabel-" + row.app.key
                title: row.latestText
                subtitle: row.metadata
            }
            RowLayout {
                spacing: 2
                Ui.FlatIconButton {
                    objectName: "notificationSilence-" + row.app.key
                    sizeRole: "secondary"
                    uiScale: Ui.Theme.expandedSecondaryActionScale
                    icon: content.controller.notificationState.appPolicy(row.app.key).silent ? "notifications" : "notifications_off"
                    accessibleName: content.controller.notificationState.appPolicy(row.app.key).silent ? qsTr("Unsilence %1").arg(row.app.latest.app_name) : qsTr("Silence %1").arg(row.app.latest.app_name)
                    enabled: content.controller.notificationState.nativeAvailable && !content.controller.notificationState.policyPending[row.app.key]
                    onClicked: content.controller.triggerAppAction("silence", row.app.key)
                }
                Ui.FlatIconButton {
                    objectName: "notificationDelete-" + row.app.key
                    sizeRole: "secondary"
                    uiScale: Ui.Theme.expandedSecondaryActionScale
                    icon: "delete"
                    accessibleName: qsTr("Delete all notifications from %1").arg(row.app.latest.app_name)
                    enabled: content.controller.notificationState.nativeAvailable && !content.controller.deleting
                    onClicked: content.controller.triggerAppAction("delete", row.app.key)
                }
            }
        }
    }
    Ui.ConfirmationDialog {
        objectName: "notificationDeleteConfirmation"
        visible: !!content.controller.notificationState.deleteConfirmation
        z: 120
        title: qsTr("Delete %1 notifications?").arg(content.controller.notificationState.deleteConfirmation?.count || 0)
        detail: content.controller.notificationState.deleteLabel + qsTr("\nIncludes notifications outside the current search. App preferences are unchanged. This cannot be undone.")
        acceptLabel: qsTr("Delete")
        onAccepted: content.controller.notificationState.confirmDelete()
        onCancelled: content.controller.notificationState.cancelDelete()
    }
    detailsComponent: NotificationDetails {
        controller: content.controller
    }
}
