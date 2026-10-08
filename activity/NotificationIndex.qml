pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import Shelllist.Core as Core

Item {
    id: page
    required property NotificationController controller
    readonly property NotificationTimeline timeline: controller.timeline
    property string anchorKey: ""
    property real anchorOffset: 0
    property bool restoring: false
    property int restoreAttempts: 0
    property int stablePasses: 0
    property bool tearingDown: false
    Component.onDestruction: tearingDown = true
    Timer { id: restoreRetry; interval: 16; onTriggered: page.restoreAnchor() }
    function captureAnchor(): void {
        if (restoring) return;
        restoreAttempts = 0; stablePasses = 0;
        const index = history.firstVisibleIndex();
        const row = index >= 0 ? history.itemAtIndex(index) : null;
        anchorKey = index >= 0 ? history.model.get(index).resultKey : "";
        anchorOffset = row ? row.y - history.contentY : 0;
        restoring = true;
    }
    function restoreAnchor(): void {
        restoreRetry.stop();
        if (!restoring) return;
        if (tearingDown || !history || !page.visible) { restoring = false; return; }
        // A bounds/flick animation must not undo the restored row offset.
        history.cancelFlick();
        history.forceLayout();
        const index = history.model.currentKeys().indexOf(anchorKey);
        if (index >= 0) {
            let item = history.itemAtIndex(index);
            if (!item || item.height <= 0) {
                history.positionViewAtIndex(index, ListView.Beginning);
                history.forceLayout();
                item = history.itemAtIndex(index);
            }
            // Incubation and variable-height layout can settle over successive
            // frames. Hold the same key/offset until two passes agree; never
            // replace that anchor with an intermediate gap or first-row offset.
            const ready = item && item.height > 0;
            stablePasses = ready && Math.abs(item.y - history.contentY - anchorOffset) < 1 ? stablePasses + 1 : 0;
            if (ready) history.contentY = Math.max(history.originY, Math.min(history.originY + Math.max(0, history.contentHeight - history.height), item.y - anchorOffset));
            if (stablePasses < 2 && restoreAttempts++ < 32) { restoreRetry.restart(); return; }
        }
        restoring = false;
        history.rememberScroll();
    }
    Connections {
        target: page.controller
        function onNavigationInteracted(): void { restoreRetry.stop(); page.restoring = false; }
    }
    Connections {
        target: page.timeline
        function onViewAboutToChange(): void { page.captureAnchor(); }
        function onViewChanged(): void { Qt.callLater(page.restoreAnchor); }
    }
    function dateLabel(key: string): string {
        return ({today: qsTr("Today"), week: qsTr("This week"), month: qsTr("This month"), older: qsTr("Older")})[key] || key;
    }
    function rows(): var {
        const result = (timeline.snapshot.recent || []).map(preview => ({kind: "message", key: Ui.NotificationPresentation.recordKey(preview), preview: preview, count: 1, stack: false}));
        for (const date of timeline.snapshot.dates || []) {
            if (!date.count) continue;
            result.push({kind: "date", key: date.key, count: date.count});
            if (date.key !== timeline.requestedDate || date.key !== timeline.snapshot.date || timeline.collapsed) continue;
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
            visible: page.timeline.totalCount === 0
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
        onMovementStarted: { restoreRetry.stop(); page.restoring = false; }
        spacing: Ui.Theme.spacingSm
        cacheBuffer: 200
        readonly property var rows: page.rows()
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
                        color: Ui.Theme.mutedText; font.pixelSize: Ui.Theme.fontSizeCaption
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
