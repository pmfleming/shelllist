pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
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
                    label: page.timeline.busy ? qsTr("Loading…") : qsTr("More notifications")
                    icon: "expand_more"
                    enabled: !page.timeline.busy && !page.timeline.error
                    onClicked: page.timeline.loadMore()
                    // This is a transport boundary, not a page control. Load
                    // when it enters the viewport; keep an explicit retry route.
                    readonly property bool inViewport: row.y < history.contentY + history.height + 80
                    onInViewportChanged: if (inViewport) Qt.callLater(page.timeline.loadMore)
                    Component.onCompleted: if (inViewport) Qt.callLater(page.timeline.loadMore)
                }
            }
            Component {
                id: message
                Ui.DetailColumnCard {
                    id: card
                    width: row.width
                    objectName: "notificationPreview-" + row.modelData.key
                    readonly property var preview: row.modelData.preview
                    color: Ui.Theme.surfaceContainer
                    Ui.ThemeText {
                        objectName: "notificationPreviewTitle-" + row.modelData.key
                        Layout.fillWidth: true
                        text: Ui.NotificationPresentation.previewHeading(card.preview)
                        visible: text.length > 0
                        textFormat: Text.PlainText
                        elide: Text.ElideRight; maximumLineCount: 1
                        font.pixelSize: Ui.Theme.fontSizeHeading
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Ui.ThemeText {
                        objectName: "notificationPreviewBody-" + row.modelData.key
                        Layout.fillWidth: true
                        text: Ui.NotificationPresentation.previewBody(card.preview)
                        visible: text.length > 0
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2
                    }
                    Ui.ThemeText {
                        objectName: "notificationPreviewMeta-" + row.modelData.key
                        Layout.fillWidth: true
                        text: Ui.NotificationPresentation.timeLabel(card.preview.created_unix_ms, page.controller.nowMs) + (row.modelData.stack ? qsTr(" · %1 similar notifications").arg(row.modelData.count) : "")
                        color: Ui.Theme.mutedText; font.pixelSize: Ui.Theme.metadataSize
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Ui.Theme.spacingSm
                        Item { Layout.fillWidth: true }
                        Ui.FlatIconButton {
                            objectName: "notificationCard-" + row.modelData.key + ":expand"
                            visible: row.modelData.stack
                            sizeRole: "secondary"
                            uiScale: Ui.Theme.expandedSecondaryActionScale
                            icon: row.modelData.expanded ? "expand_less" : "expand_more"
                            accessibleName: row.modelData.expanded ? qsTr("Collapse similar notifications") : qsTr("Expand similar notifications")
                            onClicked: page.timeline.expandedStacks = Object.assign({}, page.timeline.expandedStacks, {[row.modelData.key]: !row.modelData.expanded})
                        }
                        Ui.FlatIconButton {
                            objectName: "notificationCard-" + row.modelData.key + ":delete"
                            visible: !row.modelData.stack
                            sizeRole: "secondary"
                            uiScale: Ui.Theme.expandedSecondaryActionScale
                            icon: "delete"
                            accessibleName: qsTr("Delete this notification")
                            enabled: page.controller.notificationState.nativeAvailable && !page.controller.deleting
                            onClicked: page.controller.deleteRecord(card.preview)
                        }
                    }
                }
            }
        }
    }
}
