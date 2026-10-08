pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Item {
    id: page
    required property NotificationController controller
    readonly property NotificationTimeline timeline: controller.timeline
    property string anchorKey: ""
    property real anchorOffset: 0
    property bool restoring: false
    property bool tearingDown: false
    Component.onDestruction: tearingDown = true
    function captureAnchor(): void {
        const index = history.indexAt(1, Math.max(history.originY, history.contentY) + history.spacing + 1);
        const row = index >= 0 ? history.itemAtIndex(index) : null;
        anchorKey = index >= 0 ? history.model[index]?.key || "" : "";
        anchorOffset = row ? row.y - history.contentY : 0;
        restoring = true;
    }
    function restoreAnchor(): void {
        if (tearingDown || !history || !page.visible) { restoring = false; return; }
        const index = history.model.findIndex(row => row.key === anchorKey);
        if (index >= 0) {
            history.positionViewAtIndex(index, ListView.Beginning);
            const item = history.itemAtIndex(index);
            if (item) history.contentY = Math.max(history.originY, Math.min(history.originY + Math.max(0, history.contentHeight - history.height), item.y - anchorOffset));
        }
        restoring = false;
        history.rememberScroll();
    }
    Connections {
        target: page.timeline
        function onViewAboutToChange(): void { page.captureAnchor(); }
        function onViewChanged(): void { Qt.callLater(page.restoreAnchor); }
    }
    function dateLabel(key: string): string {
        const today = new Date(page.controller.nowMs);
        const yesterday = new Date(page.controller.nowMs); yesterday.setDate(yesterday.getDate() - 1);
        const value = new Date(key + "T12:00:00");
        return value.toDateString() === today.toDateString() ? qsTr("Today") : value.toDateString() === yesterday.toDateString() ? qsTr("Yesterday") : value.toLocaleDateString();
    }
    function rows(): var {
        const result = [];
        for (const date of timeline.snapshot.dates || []) {
            result.push({kind: "date", key: date.key, count: date.count});
            if (date.key !== timeline.snapshot.date || timeline.collapsed) continue;
            for (const entry of timeline.entries) {
                const expanded = timeline.expandedStacks[entry.key] === true;
                result.push({kind: "message", key: entry.key, preview: entry.preview, count: entry.members.length, stack: entry.members.length > 1, expanded: expanded});
                if (expanded) for (const member of entry.members) {
                    result.push({kind: "message", key: "member:" + member.id + ":" + member.created,
                        preview: Object.assign({}, entry.preview, {id: member.id, created_unix_ms: member.created}), count: 1, stack: false});
                }
            }
            if (timeline.hasMore || timeline.busy) result.push({kind: "more", key: "more"});
        }
        return result;
    }
    Column {
        id: header
        width: parent.width
        spacing: Ui.Theme.spacingSm
        NotificationAppHeader { width: parent.width; controller: page.controller }
        Ui.ThemeText {
            width: parent.width; text: page.timeline.error; visible: text.length > 0
            color: Ui.Theme.danger; wrapMode: Text.WordWrap
        }
        Ui.LabeledAction {
            width: parent.width; visible: !!page.timeline.error
            icon: "refresh"; label: qsTr("Retry notification history"); accessKey: "T"
            uiScale: Ui.Theme.expandedSecondaryActionScale
            onClicked: page.timeline.refresh()
        }
        Ui.ContentState {
            width: parent.width
            visible: !(page.timeline.snapshot.dates || []).length
            icon: "notifications_none"
            kind: page.timeline.error ? "unavailable" : page.timeline.busy ? "loading" : page.controller.catalog.query ? "filtered" : "empty"
            text: page.timeline.error || (kind === "loading" ? qsTr("Loading notifications…") : kind === "filtered" ? qsTr("No matching notifications") : qsTr("No notifications"))
        }
    }
    Ui.DetailListView {
        id: history
        objectName: "notificationTimelineList"
        anchors.top: header.bottom; anchors.topMargin: Ui.Theme.spacingMd
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        viewMemory: page.controller.viewMemory
        memoryTab: "notifications"
        scrollSuspended: page.restoring
        spacing: Ui.Theme.spacingSm
        cacheBuffer: 200
        model: page.rows()
        delegate: Ui.CommandGroup {
            id: row
            required property var modelData
            width: history.width
            Loader {
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
                    icon: page.timeline.snapshot.date === row.modelData.key && !page.timeline.collapsed ? "expand_less" : "expand_more"
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
                        color: Ui.Theme.mutedText; font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                    Ui.SurfaceActionRow {
                        Layout.fillWidth: true
                        headerCommands: false
                        compactSecondaryActions: true
                        actionObjectNamePrefix: "notificationCard-" + row.modelData.key + ":"
                        actions: [
                            {id: "expand", label: row.modelData.expanded ? qsTr("Collapse similar notifications") : qsTr("Expand similar notifications"), icon: row.modelData.expanded ? "expand_less" : "expand_more", visible: row.modelData.stack, presentation: {group: "toolbar"}},
                            {id: "read", label: qsTr("Read %1").arg(card.preview.summary || qsTr("notification")), icon: "chevron_right", presentation: {group: "toolbar"}},
                            {id: "delete", label: qsTr("Delete this notification"), icon: "delete", visible: !row.modelData.stack, enabled: page.controller.notificationState.nativeAvailable && !page.controller.deleting, presentation: {group: "toolbar"}}
                        ]
                        onTriggered: function (id) {
                            if (id === "read") page.controller.readRecord(card.preview);
                            else if (id === "delete") page.controller.deleteRecord(card.preview);
                            else page.timeline.expandedStacks = Object.assign({}, page.timeline.expandedStacks, {[row.modelData.key]: !row.modelData.expanded});
                        }
                    }
                }
            }
        }
    }
}
