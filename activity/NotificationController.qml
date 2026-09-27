import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Io as Io
import Shelllist.Core as Core

Ui.ChooserController {
    id: controller

    property NotificationState notificationState: NotificationState {
        uiActive: controller.uiActive
        historyEnabled: controller.uiActive
    }
    property string tab: "active"
    property alias filterText: groupSelection.queryText
    property string returnSurface: ""
    property string pendingGroupKey: ""
    property string selectedGroupKey: ""
    property double nowMs: Date.now()
    property alias screenshotStatus: screenshotCapture.statusMessage
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
    readonly property alias groupModel: groups
    readonly property var visibleGroups: Ui.NotificationPresentation.groupRecords(Ui.NotificationPresentation.filterRecords(tab === "active" ? Ui.NotificationPresentation.newestFirst(notificationState.activeNotifications) : notificationState.history, filterText))

    readonly property var selectedGroup: visibleGroups.find(group => group.key === selectedGroupKey) || null
    hasSelection: selectedGroup !== null
    selectionModel: groupSelection
    viewMemory: Ui.ChooserMemory {
        controller: controller
        key: controller.selectedGroupKey ? "notifications::" + controller.tab + "::" + controller.selectedGroupKey : ""
        tab: "messages"
        tabs: ["messages"]
        onRestoreRequested: function (open, tab) {
            controller.detailsOpen = open && controller.hasSelection;
            if (controller.detailsOpen)
                controller.expandSelected(true);
        }
    }
    QtObject {
        id: groupSelection
        property int selectedIndex: 0
        property string queryText: ""
        onSelectedIndexChanged: {
            const group = controller.visibleGroups[selectedIndex];
            if (group)
                controller.selectedGroupKey = group.key;
        }
        function move(delta: int): void { controller.moveGroup(delta); }
        function selectFirst(): void { controller.select(0); }
    }
    onSelectedGroupKeyChanged: groupSelection.selectedIndex = Math.max(0, visibleGroups.findIndex(group => group.key === selectedGroupKey))
    function select(index): void {
        if (visibleGroups[index])
            selectedGroupKey = visibleGroups[index].key;
    }
    function resultKeyAt(index: int): string {
        return visibleGroups[index] ? "notifications::" + tab + "::" + visibleGroups[index].key : "";
    }
    function resultIndexForKey(key: string): int {
        return visibleGroups.findIndex(group => "notifications::" + tab + "::" + group.key === key);
    }
    function setPower() { notificationState.setDndEnabled(!notificationState.notifications.dnd); }
    function openDetails() {
        viewMemory.synchronize();
        if (hasSelection) {
            detailsOpen = true;
            expandSelected(true);
        }
    }
    function primarySelected(): bool {
        openDetails();
        focusDetailsRequested();
        return hasSelection;
    }

    signal backRequested
    signal groupsAboutToChange
    signal groupsUpdated
    signal revealGroupRequested(string key)

    function openNotifications(key: string, requestedTab: string, origin: string): void {
        returnSurface = origin;
        filterText = "";
        tab = requestedTab === "history" ? "history" : "active";
        pendingGroupKey = key;
        if (key)
            notificationState.setExpanded(key, true);
        rebuildGroups();
    }
    function goBack(): void {
        if (returnSurface === "activity")
            backRequested();
        else
            closeWindowRequested();
    }
    function dismissNavigation(): bool {
        if (detailsOpen)
            closeDetails();
        else
            goBack();
        return true;
    }
    function captureScreenshot(x: real, y: real, width: real, height: real): bool {
        return screenshotCapture.captureRegion(x, y, width, height);
    }
    function refresh(): void {
        notificationState.backend.snapshot();
        notificationState.reloadHistory();
    }
    function rebuildGroups(): void {
        groupsAboutToChange();
        groups.rows = visibleGroups.map(group => ({
                    key: group.key,
                    payload: group
                }));
        if (!visibleGroups.some(function (group) {
            return group.key === controller.selectedGroupKey;
        }))
            selectedGroupKey = visibleGroups.length ? visibleGroups[0].key : "";
        groupSelection.selectedIndex = Math.max(0, visibleGroups.findIndex(group => group.key === selectedGroupKey));
        groupsUpdated();
        revealPendingGroup();
    }
    function revealPendingGroup(): void {
        if (pendingGroupKey && visibleGroups.some(function (group) {
            return group.key === controller.pendingGroupKey;
        })) {
            selectedGroupKey = pendingGroupKey;
            revealGroupRequested(pendingGroupKey);
            pendingGroupKey = "";
            openDetails();
        }
    }
    function moveGroup(delta: int): void {
        const index = visibleGroups.findIndex(function (group) {
            return group.key === controller.selectedGroupKey;
        });
        const next = Math.max(0, Math.min(visibleGroups.length - 1, index + delta));
        if (visibleGroups.length) {
            selectedGroupKey = visibleGroups[next].key;
            revealGroupRequested(selectedGroupKey);
        }
    }
    function expandSelected(expand: bool): void {
        if (selectedGroupKey)
            notificationState.setExpanded(selectedGroupKey, expand);
    }
    function activateUi(workspaceId): void {
        activateUiState(workspaceId);
        nowMs = Date.now();
        Qt.callLater(revealPendingGroup);
    }
    function deactivateUi(): void {
        deactivateUiState();
        returnSurface = "";
        // Deliberately retain search, scroll, expansion and reply drafts.
    }

    Io.ClipboardScreenshotCapture {
        id: screenshotCapture
        active: controller.uiActive
        startMessage: "Capturing Notifications panel…"
    }

    onVisibleGroupsChanged: rebuildGroups()
    Core.SerializedListModel {
        id: groups
    }
    Timer {
        interval: 30000
        repeat: true
        running: controller.uiActive
        onTriggered: controller.nowMs = Date.now()
    }
}
