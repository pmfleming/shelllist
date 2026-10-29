pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Core as Core

Item {
    id: page
    required property NotificationController controller
    readonly property NotificationTimeline timeline: controller.timeline
    Connections {
        target: page.controller
        function onNavigationInteracted(): void { history.cancelAnchor(); }
    }
    Connections {
        target: page.timeline
        function onViewAboutToChange(): void { history.captureAnchor(); }
        function onWindowReplaced(): void {
            history.cancelAnchor();
            page.controller.viewMemory.rememberPage("notifications", {scroll: 0, scrollKey: "", scrollOffset: 0});
            history.forceLayout();
            history.positionViewAtBeginning();
        }
        function onViewChanged(): void { Qt.callLater(history.restoreAnchor); }
    }
    function dateLabel(key: string): string {
        return ({today: qsTr("Today"), week: qsTr("This week"), month: qsTr("This month"), older: qsTr("Older")})[key] || key;
    }
    Column {
        id: header
        width: parent.width
        spacing: Ui.Theme.spacingSm
        NotificationAppHeader { width: parent.width; controller: page.controller }
        Ui.ActionButton {
            objectName: "notificationLatestHistory"
            label: qsTr("Latest notifications in period")
            icon: "arrow_upward"
            accessKey: "B"
            visible: page.timeline.windowOffset > 0
            enabled: !page.timeline.busy && !page.controller.navigationBlocked
            onClicked: page.timeline.showRecent()
        }
        Ui.ActionButton {
            objectName: "notificationOlderHistory"
            label: qsTr("Load older notifications")
            icon: "expand_more"
            accessKey: "L"
            visible: page.timeline.cacheFull && page.timeline.hasMore
            enabled: !page.timeline.busy && !page.timeline.error && !page.controller.navigationBlocked
            onClicked: page.timeline.loadMore()
        }
        Ui.ContentState {
            width: parent.width
            visible: page.timeline.totalCount === 0
            icon: "notifications_none"
            kind: page.timeline.error ? "unavailable" : page.timeline.busy ? "loading" : page.controller.catalog.query ? "filtered" : "empty"
            text: page.timeline.error ? qsTr("Notification history unavailable") : (kind === "loading" ? qsTr("Loading notifications…") : kind === "filtered" ? qsTr("No matching notifications") : qsTr("No notifications"))
        }
    }
    Ui.DetailListView {
        id: history
        objectName: "notificationTimelineList"
        anchors.top: header.bottom; anchors.topMargin: Ui.Theme.spacingMd
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        viewMemory: page.controller.viewMemory
        memoryTab: "notifications"
        spacing: Ui.Theme.spacingSm
        cacheBuffer: 200
        readonly property var rows: Ui.NotificationPresentation.timelineRows(page.timeline.snapshot,
            page.timeline.requestedDate, page.timeline.collapsed, page.timeline.entries,
            page.timeline.expandedStacks, page.timeline.hasMore || page.timeline.busy)
        model: Core.SerializedListModel {
            rows: history.rows.map(row => ({key: row.key, payload: row}))
        }
        delegate: Ui.CommandGroup {
            id: row
            required property var resultData
            readonly property var modelData: JSON.parse(resultData.payload)
            width: history.width
            // Column's implicit height settles a positioning pass later. Feed
            // the loader height directly to ListView so it never estimates a
            // newly created message as a zero-height row.
            height: rowContent.height
            Loader {
                id: rowContent
                width: parent.width
                sourceComponent: row.modelData.kind === "date" ? dateHeader : row.modelData.kind === "more" ? more : message
            }
            Component {
                id: dateHeader
                Ui.LabeledAction {
                    width: row.width
                    uiScale: Ui.Theme.expandedSecondaryActionScale
                    objectName: "notificationDate-" + row.modelData.key
                    // Pad period rows without enlarging their disclosure buttons.
                    height: implicitHeight + 2 * Ui.Theme.spacingSm
                    label: page.dateLabel(row.modelData.key) + " · " + row.modelData.count
                    icon: page.timeline.requestedDate === row.modelData.key && !page.timeline.collapsed ? "expand_less" : "expand_more"
                    enabled: row.modelData.count > 0
                    onClicked: page.timeline.chooseDate(row.modelData.key)
                }
            }
            Component {
                id: more
                Ui.LabeledAction {
                    width: row.width
                    uiScale: Ui.Theme.expandedSecondaryActionScale
                    label: page.timeline.busy ? qsTr("Loading…") : page.timeline.cacheFull ? qsTr("Load older notifications") : qsTr("More notifications")
                    icon: "expand_more"
                    enabled: !page.timeline.busy && !page.timeline.error && !page.controller.navigationBlocked
                    onClicked: page.timeline.loadMore()
                    // Automatic reads stop at the working-set boundary. Only
                    // an explicit command replaces an already full window.
                    readonly property bool inViewport: row.y < history.contentY + history.height + 80
                    onInViewportChanged: if (inViewport) Qt.callLater(page.timeline.autoLoadMore)
                    Component.onCompleted: if (inViewport) Qt.callLater(page.timeline.autoLoadMore)
                }
            }
            Component {
                id: message
                NotificationPreviewCard {
                    width: row.width
                    entry: row.modelData
                    nowMs: page.controller.nowMs
                    deleteEnabled: page.controller.notificationState.nativeAvailable && !page.controller.deleting
                    onExpansionRequested: page.timeline.expandedStacks = Object.assign({}, page.timeline.expandedStacks, {[row.modelData.key]: !row.modelData.expanded})
                    onDeleteRequested: function (record) { page.controller.deleteRecord(record); }
                }
            }
        }
    }
}
