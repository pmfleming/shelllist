pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: pane
    required property NotificationController controller
    readonly property NotificationState notificationState: controller.notificationState
    property string scrollAnchorKey: ""
    property real scrollAnchorOffset: 0

    radius: Ui.Theme.panelRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border

    function focusList(): void {
        list.forceActiveFocus();
    }

    function revealGroup(key: string): void {
        const index = controller.visibleGroups.findIndex(function (group) {
            return group.key === key;
        });
        if (index >= 0) {
            list.currentIndex = index;
            list.positionViewAtIndex(index, ListView.Contain);
        }
    }

    Ui.ThemeText {
        id: errorText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: visible ? Ui.Theme.spacingMd : 0
        visible: text.length > 0
        height: visible ? implicitHeight : 0
        text: pane.notificationState.lastError || (pane.controller.tab === "history" ? pane.notificationState.historyError : "")
        color: Ui.Theme.danger
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeSmall
    }

    Ui.ScrollableListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: errorText.bottom
        anchors.bottom: parent.bottom
        anchors.margins: Ui.Theme.spacingMd
        clip: true
        spacing: Ui.Theme.spacingSm
        model: pane.controller.groupModel
        activeFocusOnTab: true
        keyNavigationEnabled: false
        delegate: NotificationHistoryGroup {
            required property string payload
            group: JSON.parse(payload)
            controller: pane.controller
        }
        Keys.onDownPressed: pane.controller.moveGroup(1)
        Keys.onUpPressed: pane.controller.moveGroup(-1)
        Keys.onRightPressed: pane.controller.expandSelected(true)
        Keys.onLeftPressed: pane.controller.expandSelected(false)
        Keys.onReturnPressed: pane.controller.expandSelected(true)

        readonly property bool shouldLoadMore: pane.controller.tab === "history" && pane.notificationState.historyHasMore && !pane.notificationState.historyLoading && !pane.notificationState.historyError && count > 0 && contentHeight > 0 && contentY - originY + height >= contentHeight - height * 0.5
        onShouldLoadMoreChanged: if (shouldLoadMore)
            Qt.callLater(pane.notificationState.loadMoreHistory)

        footer: Item {
            width: ListView.view ? ListView.view.width : 0
            height: pane.controller.tab === "history" && pane.notificationState.historyLoading && pane.notificationState.history.length > 0 ? Ui.Theme.controlHeight : 0
            visible: height > 0
            Ui.ThemeText {
                anchors.centerIn: parent
                text: "Loading…"
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeCaption
            }
        }

        Column {
            objectName: "notificationEmptyState"
            anchors.centerIn: parent
            width: parent.width - 40
            visible: pane.controller.visibleGroups.length === 0
            spacing: Ui.Theme.spacingSm
            readonly property bool loading: pane.controller.tab === "history" && (pane.notificationState.historyLoading || (!pane.notificationState.historyLoaded && !pane.notificationState.historyError))
            readonly property bool filtered: pane.controller.filterText.trim().length > 0

            Ui.GlyphLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                glyph: parent.filtered ? "󰍉" : pane.controller.tab === "history" ? "󰋚" : pane.notificationState.notifications.dnd ? "󰂛" : "󰂚"
                color: Ui.Theme.subtleText
                font.pixelSize: 40
            }
            Ui.ThemeText {
                width: parent.width
                text: {
                    if (parent.loading)
                        return "Loading…";
                    if (pane.controller.tab === "history" && pane.notificationState.historyError)
                        return "History unavailable";
                    if (parent.filtered)
                        return "No matches";
                    if (pane.controller.tab === "history")
                        return "No history";
                    return pane.notificationState.notifications.available ? "All caught up" : "Notifications unavailable";
                }
                color: Ui.Theme.mutedText
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }
    }
    Connections {
        target: pane.controller
        function onRevealGroupRequested(key: string): void {
            Qt.callLater(function () {
                pane.revealGroup(key);
            });
        }
        function onGroupsAboutToChange(): void {
            const index = list.indexAt(1, list.contentY + 1);
            const item = index >= 0 ? list.itemAtIndex(index) : null;
            pane.scrollAnchorKey = item ? item.group.key : "";
            pane.scrollAnchorOffset = item ? list.contentY - item.y : 0;
        }
        function onGroupsUpdated(): void {
            const key = pane.scrollAnchorKey;
            const offset = pane.scrollAnchorOffset;
            if (!key)
                return;
            Qt.callLater(function () {
                const index = pane.controller.visibleGroups.findIndex(function (group) {
                    return group.key === key;
                });
                if (index < 0)
                    return;
                list.positionViewAtIndex(index, ListView.Beginning);
                const item = list.itemAtIndex(index);
                if (item)
                    list.contentY = item.y + offset;
                list.returnToBounds();
            });
        }
    }
    Component.onCompleted: Qt.callLater(function () {
        pane.revealGroup(pane.controller.selectedGroupKey);
    })
}
