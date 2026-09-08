import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Io as Io

Ui.ChooserController {
    id: controller

    property NotificationState notificationState: NotificationState {
        uiActive: controller.uiActive
        historyEnabled: controller.uiActive
    }
    property string tab: "active"
    property string filterText: ""
    property string returnSurface: ""
    property string pendingGroupKey: ""
    property string selectedGroupKey: ""
    property double nowMs: Date.now()
    property string screenshotStatus: ""
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
    readonly property alias groupModel: groups
    readonly property var visibleGroups: Ui.NotificationPresentation.groupRecords(
        Ui.NotificationPresentation.filterRecords(tab === "active"
            ? Ui.NotificationPresentation.newestFirst(notificationState.activeNotifications)
            : notificationState.history, filterText))

    navigationPrimaryEnabled: false
    closedWidthFraction: 0.4
    openWidthFraction: closedWidthFraction
    minimumClosedWindowWidth: 453
    maximumClosedWindowWidth: 640
    minimumOpenWindowWidth: minimumClosedWindowWidth
    maximumOpenWindowWidth: maximumClosedWindowWidth
    surfaceHeightRatio: Ui.Theme.popupHeightRatio
    surfaceAlignment: "center"

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
    function dismissNavigation(): bool { goBack(); return true; }
    function captureScreenshot(x: real, y: real, width: real, height: real): bool {
        return screenshotCapture.captureRegion(x, y, width, height);
    }
    function refresh(): void {
        notificationState.backend.snapshot();
        notificationState.reloadHistory();
    }
    function rebuildGroups(): void {
        groupsAboutToChange();
        Ui.NotificationPresentation.syncKeyedModel(groups, visibleGroups.map(function (group) {
            return { key: group.key, payload: group };
        }));
        if (!visibleGroups.some(function (group) { return group.key === controller.selectedGroupKey; }))
            selectedGroupKey = visibleGroups.length ? visibleGroups[0].key : "";
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
        onStatusChanged: function (message) {
            controller.screenshotStatus = message;
            if (!inFlight)
                screenshotStatusTimer.restart();
        }
    }
    Timer {
        id: screenshotStatusTimer
        interval: 2500
        onTriggered: controller.screenshotStatus = ""
    }

    onVisibleGroupsChanged: rebuildGroups()
    ListModel { id: groups; dynamicRoles: true }
    Timer {
        interval: 30000
        repeat: true
        running: controller.uiActive
        onTriggered: controller.nowMs = Date.now()
    }
}
