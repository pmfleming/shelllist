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

    function revealGroup(key: string): void {
        const index = controller.visibleGroups.findIndex(function (group) { return group.key === key; });
        if (index >= 0) {
            list.currentIndex = index;
            list.positionViewAtIndex(index, ListView.Contain);
        }
    }

    Column {
        id: toolbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Ui.Theme.spacingMd
        spacing: Ui.Theme.spacingSm

        Flow {
            width: parent.width
            spacing: Ui.Theme.spacingSm
            Ui.DropDownList {
                width: Math.min(180, parent.width)
                height: 36
                objectName: "notificationDnd"
                value: pane.notificationState.notifications.dnd ? "-1" : "0"
                options: [
                    { value: "-1", label: Ui.NotificationPresentation.dndLabel(
                        pane.notificationState.notifications, pane.controller.nowMs) },
                    { value: "0", label: "DND off" },
                    { value: "30", label: "Pause for 30 min" },
                    { value: "60", label: "Pause for 1 hour" },
                    { value: "120", label: "Pause for 2 hours" },
                    { value: "480", label: "Pause for 8 hours" }
                ]
                onSelected: function (minutes) {
                    if (Number(minutes) >= 0) pane.notificationState.setDndForMinutes(Number(minutes));
                }
            }
            Ui.ActionButton {
                width: Math.min(164, parent.width)
                height: 36
                label: "Dismiss all active"
                enabled: pane.notificationState.activeNotifications.length > 0
                toolTip: "Dismiss across all apps, including snoozed notifications; history is kept"
                onClicked: pane.notificationState.clearNotifications()
            }
        }
        Flow {
            width: parent.width
            spacing: Ui.Theme.spacingSm
            ActivityHeaderButton {
                label: "Active " + pane.notificationState.activeNotifications.length
                checked: pane.controller.tab === "active"
                onTriggered: pane.controller.tab = "active"
            }
            ActivityHeaderButton {
                label: "History"
                checked: pane.controller.tab === "history"
                onTriggered: pane.controller.tab = "history"
            }
            Text {
                height: 34
                verticalAlignment: Text.AlignVCenter
                text: pane.controller.tab === "history"
                    ? pane.notificationState.history.length + " loaded" : ""
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
            }
        }
        Ui.TextField {
            id: search
            width: parent.width
            height: 36
            placeholder: pane.controller.tab === "history"
                ? "Search loaded history…" : "Search app, title or message…"
            text: pane.controller.filterText
            onEdited: function (value) { pane.controller.filterText = value; }
            onKeyPressed: function (event) {
                if (event.key === Qt.Key_Down) {
                    list.forceActiveFocus();
                    event.accepted = true;
                }
            }
        }
        Text {
            visible: pane.notificationState.draftCount > 0
            width: parent.width
            text: pane.notificationState.draftCount
                + (pane.notificationState.draftCount === 1 ? " unsent draft" : " unsent drafts")
                + " · retained when closed"
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
        Text {
            visible: text.length > 0
            width: parent.width
            text: pane.notificationState.lastError || (pane.controller.tab === "history"
                ? pane.notificationState.historyError : "")
            color: Ui.Theme.danger
            wrapMode: Text.Wrap
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
    }

    Ui.ScrollableListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: toolbar.bottom
        anchors.bottom: footer.top
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

        Text {
            anchors.centerIn: parent
            width: parent.width - 20
            visible: pane.controller.visibleGroups.length === 0
            text: {
                if (pane.controller.tab === "history" && (pane.notificationState.historyLoading
                        || (!pane.notificationState.historyLoaded && !pane.notificationState.historyError)))
                    return "Loading history…";
                if (pane.controller.tab === "history" && pane.notificationState.historyError)
                    return "Could not load history. Use Refresh to retry.";
                if (pane.controller.filterText.trim())
                    return "No matching notifications";
                if (pane.controller.tab === "history")
                    return "No notification history";
                return pane.notificationState.notifications.available
                    ? "No active notifications · History is still available"
                    : "Notifications unavailable";
            }
            color: Ui.Theme.mutedText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
    }
    Flow {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Ui.Theme.spacingMd
        spacing: Ui.Theme.spacingSm
        Ui.ActionButton {
            width: 88
            height: 34
            label: "Refresh"
            enabled: !pane.notificationState.historyLoading
            onClicked: pane.controller.refresh()
        }
        Ui.ActionButton {
            visible: pane.controller.tab === "history" && pane.notificationState.historyHasMore
            width: Math.min(190, parent.width)
            height: 34
            label: pane.notificationState.historyLoading ? "Loading…" : "Load older notifications"
            enabled: !pane.notificationState.historyLoading
            onClicked: pane.notificationState.loadMoreHistory()
        }
    }
    Connections {
        target: pane.controller
        function onFocusSearchRequested(): void { search.focusInput(false); }
        function onRevealGroupRequested(key: string): void {
            Qt.callLater(function () { pane.revealGroup(key); });
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
            if (!key) return;
            Qt.callLater(function () {
                const index = pane.controller.visibleGroups.findIndex(function (group) {
                    return group.key === key;
                });
                if (index < 0) return;
                list.positionViewAtIndex(index, ListView.Beginning);
                const item = list.itemAtIndex(index);
                if (item) list.contentY = item.y + offset;
                list.returnToBounds();
            });
        }
    }
    Component.onCompleted: Qt.callLater(function () {
        pane.revealGroup(pane.controller.selectedGroupKey);
    })
}
