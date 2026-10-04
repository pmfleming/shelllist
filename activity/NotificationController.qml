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
    property alias filterText: recordSelection.queryText
    property string returnSurface: ""
    property string pendingGroupKey: ""
    property string selectedKey: ""
    property double nowMs: Date.now()
    property alias screenshotStatus: screenshotCapture.statusMessage
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
    readonly property alias notificationModel: records
    readonly property var visibleRecords: Ui.NotificationPresentation.filterRecords(notificationState.recentNotifications, filterText)
    readonly property var selectedRecord: visibleRecords.find(record => Ui.NotificationPresentation.recordKey(record) === selectedKey) || null

    hasSelection: selectedRecord !== null
    selectionModel: recordSelection
    viewMemory: Ui.ChooserMemory {
        controller: controller
        key: controller.selectedKey ? "notifications::" + controller.selectedKey : ""
        tab: "message"
        tabs: ["message"]
        onRestoreRequested: function (open, tab) {
            controller.detailsOpen = open && controller.hasSelection;
        }
    }
    QtObject {
        id: recordSelection
        // Identity owns selection. Never feed a derived index back into the key
        // while the list is being reconciled/reordered.
        readonly property int selectedIndex: Math.max(0, controller.visibleRecords.findIndex(record => Ui.NotificationPresentation.recordKey(record) === controller.selectedKey))
        property string queryText: ""
        function move(delta: int): void { controller.select(selectedIndex + delta); }
        function selectFirst(): void { controller.select(0); }
    }
    function select(index): void {
        const record = visibleRecords[Math.max(0, Math.min(visibleRecords.length - 1, index))];
        if (record)
            selectedKey = Ui.NotificationPresentation.recordKey(record);
    }
    function resultKeyAt(index: int): string {
        return visibleRecords[index] ? "notifications::" + Ui.NotificationPresentation.recordKey(visibleRecords[index]) : "";
    }
    function resultIndexForKey(key: string): int {
        return visibleRecords.findIndex(record => "notifications::" + Ui.NotificationPresentation.recordKey(record) === key);
    }
    function setPower() { notificationState.setDndEnabled(!notificationState.notifications.dnd); }
    function primarySelected(): bool {
        openDetails();
        focusDetailsRequested();
        return hasSelection;
    }

    signal backRequested

    // Older bar/agenda entry points can still request active/history. Both now
    // resolve to the unified list; a group link reveals its newest message.
    function openNotifications(key: string, requestedTab: string, origin: string): void {
        returnSurface = origin;
        filterText = "";
        pendingGroupKey = key;
        revealPendingGroup();
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
    function rebuildRecords(): void {
        const oldIndex = records.currentKeys().indexOf(selectedKey);
        records.rows = visibleRecords.map(record => ({key: Ui.NotificationPresentation.recordKey(record), payload: record}));
        if (!selectedRecord) {
            selectedKey = "";
            select(Math.max(0, oldIndex));
        }
        if (!hasSelection)
            detailsOpen = false;
        revealPendingGroup();
    }
    function revealPendingGroup(): void {
        if (!pendingGroupKey)
            return;
        const index = visibleRecords.findIndex(record => Ui.NotificationPresentation.groupKey(record) === pendingGroupKey);
        if (index >= 0) {
            select(index);
            pendingGroupKey = "";
            openDetails();
        }
    }
    function activateUi(workspaceId): void {
        activateUiState(workspaceId);
        nowMs = Date.now();
        Qt.callLater(revealPendingGroup);
    }
    function deactivateUi(): void {
        deactivateUiState();
        returnSurface = "";
        // Deliberately retain search, scroll and reply drafts.
    }

    Io.ClipboardScreenshotCapture {
        id: screenshotCapture
        active: controller.uiActive
        startMessage: "Capturing Notifications panel…"
    }

    onVisibleRecordsChanged: rebuildRecords()
    Core.SerializedListModel { id: records }
    Timer {
        interval: 30000
        repeat: true
        running: controller.uiActive
        onTriggered: controller.nowMs = Date.now()
    }
}
