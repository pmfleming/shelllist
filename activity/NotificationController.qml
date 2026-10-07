import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Io as Io
import Shelllist.Core as Core

Ui.ChooserController {
    id: controller
    property NotificationState notificationState: NotificationState { uiActive: controller.uiActive }
    property alias filterText: appSelection.queryText
    property string returnSurface: ""
    property string selectedAppKey: ""
    property string selectedKey: ""
    property string detailsTab: "overview"
    property bool settingsOpen: false
    property bool messageWasOpen: false
    property string replyKey: ""
    property bool replyEditorFocused: false
    property string copyStatus: ""
    property double nowMs: Date.now()
    property var appViews: ({})
    property string presentedQuery: ""
    property string pendingGroupKey: ""
    property string pendingAppKey: ""
    property int entryGeneration: 0
    property alias screenshotStatus: screenshotCapture.statusMessage
    readonly property bool screenshotInFlight: screenshotCapture.inFlight
    readonly property alias notificationModel: records
    readonly property alias catalog: nativeCatalog
    property var visibleApps: []
    readonly property var selectedApp: visibleApps.find(app => app.key === selectedAppKey) || null
    readonly property var selectedRecord: catalog.detail.selected && Ui.NotificationPresentation.recordKey(catalog.detail.selected) === selectedKey ? catalog.detail.selected : null
    readonly property var selectedNotification: Ui.NotificationPresentation.notificationFor(selectedRecord)
    readonly property bool selectedLive: !!selectedRecord && notificationState.isLive(selectedRecord)
    readonly property bool selectedBusy: !!notificationState.operations[selectedKey]
    readonly property bool messageCommandsEnabled: detailsOpen && !settingsOpen && detailsTab === "message" && !!selectedRecord && !catalog.detailError
    readonly property var selectedAppActions: messageCommandsEnabled && selectedLive ? Ui.NotificationPresentation.standardActions(selectedNotification) : []
    readonly property bool replyVisible: messageCommandsEnabled && (replyKey === selectedKey || !!notificationState.drafts[selectedKey] || !!notificationState.replies[selectedKey])
    readonly property var tabs: [
        {value: "overview", label: qsTr("Overview")},
        {value: "notifications", label: qsTr("Notifications")},
        {value: "message", label: qsTr("Message"), enabled: selectedKey.length > 0}
    ]
    hasSelection: selectedApp !== null
    selectionModel: appSelection
    viewMemory: Ui.ChooserMemory {
        controller: controller
        key: controller.settingsOpen ? "notifications::settings" : "notifications::app::" + controller.selectedAppKey
        tab: controller.settingsOpen ? "settings" : controller.detailsTab + (controller.detailsTab === "message" ? "::" + controller.selectedKey : "")
        tabs: ["overview", "notifications", "message", "settings"]
        onRestoreRequested: function (open, tab) { controller.detailsOpen = open && (controller.settingsOpen || controller.hasSelection); }
    }
    QtObject {
        id: appSelection
        property string queryText: ""
        readonly property int selectedIndex: Math.max(0, controller.visibleApps.findIndex(app => app.key === controller.selectedAppKey))
        function move(delta: int): void { controller.select(selectedIndex + delta); }
        function selectFirst(): void { controller.select(0); }
    }
    NotificationCatalog {
        id: nativeCatalog
        store: controller.notificationState
        active: controller.uiActive
        query: controller.filterText.trim().toLowerCase()
        appKey: controller.selectedAppKey
        selectedKey: controller.selectedKey
        onAppsChanged: Qt.callLater(controller.rebuildRecords)
        onQueryChanged: {
            controller.entryGeneration++;
            controller.selectedKey = "";
            controller.replyKey = "";
            if (controller.detailsTab === "message") controller.detailsTab = "overview";
        }
    }
    function memoryKey(): string { return JSON.stringify([catalog.query, selectedAppKey]); }
    function rememberApp(): void {
        if (!selectedAppKey) return;
        appViews = Object.assign({}, appViews, {[memoryKey()]: {tab: detailsTab, key: selectedKey, page: catalog.page}});
    }
    function select(index: int): void {
        const app = visibleApps[Math.max(0, Math.min(visibleApps.length - 1, index))];
        if (!app) return;
        settingsOpen = false;
        if (selectedAppKey === app.key) return;
        detailsClosing();
        viewMemory.synchronize();
        rememberApp();
        selectedAppKey = app.key;
        const memory = appViews[memoryKey()] || ({});
        selectedKey = memory.key || "";
        detailsTab = memory.tab === "message" && !selectedKey ? "overview" : memory.tab || "overview";
        catalog.page = memory.page || 1;
        replyKey = "";
    }
    function resultKeyAt(index: int): string { return visibleApps[index] ? "notification-app::" + visibleApps[index].key : ""; }
    function resultIndexForKey(key: string): int { return visibleApps.findIndex(app => "notification-app::" + app.key === key); }
    function rebuildRecords(): void {
        const next = catalog.apps;
        const rows = next.map(app => ({key: app.key, payload: app}));
        const changed = records.count !== rows.length || rows.some((row, index) => records.get(index).resultKey !== row.key || records.get(index).resultData.payload !== JSON.stringify(row.payload));
        if (!changed) return;
        const oldIndex = records.currentKeys().indexOf(selectedAppKey);
        resultsAboutToChange(presentedQuery === catalog.query);
        visibleApps = next;
        records.rows = rows;
        if (!selectedApp) {
            if (visibleApps.length) select(Math.max(0, Math.min(visibleApps.length - 1, oldIndex)));
            else {
                detailsClosing(); selectedAppKey = ""; selectedKey = "";
                if (!settingsOpen) detailsOpen = false;
            }
        }
        presentedQuery = catalog.query;
        resultsChanged();
        if (pendingAppKey) {
            const index = visibleApps.findIndex(app => app.key === pendingAppKey);
            if (index >= 0) {
                select(index); pendingAppKey = ""; catalog.revealKey = ""; openDetails();
            }
        }
    }
    function setDetailsTab(tab: string): void {
        if (settingsOpen || !tabs.some(item => item.value === tab && item.enabled !== false) || tab === detailsTab) return;
        detailsClosing();
        viewMemory.synchronize();
        detailsTab = tab;
        rememberApp();
    }
    function cycleDetailsTab(backwards: bool): void {
        setDetailsTab(tabAfter(tabs.filter(tab => tab.enabled !== false).map(tab => tab.value), detailsTab, backwards));
    }
    function readRecord(preview: var): void {
        if (!hasSelection || preview.app_key !== selectedAppKey || !catalog.validPreview(preview)) return;
        detailsClosing();
        viewMemory.synchronize();
        selectedKey = Ui.NotificationPresentation.recordKey(preview);
        replyKey = "";
        detailsTab = "message";
        openDetails();
        rememberApp();
    }
    function primarySelected(): bool {
        if (!hasSelection || settingsOpen) return false;
        setDetailsTab("notifications");
        openDetails();
        return true;
    }
    function openSelected(): bool {
        const action = selectedLive ? Ui.NotificationPresentation.defaultAction(selectedNotification) : null;
        return !!action && invokeAction(action.key);
    }
    function invokeAction(key: string): bool {
        return messageCommandsEnabled && selectedLive && notificationState.invokeNotificationAction(selectedNotification.id, key);
    }
    function requestReply(): void {
        if (!messageCommandsEnabled || !selectedLive || !Ui.NotificationPresentation.replyAction(selectedNotification)) return;
        replyKey = selectedKey;
        focusDetailsRequested();
        replyFocusRequested();
    }
    function copySelected(): bool {
        return messageCommandsEnabled && clipboard.publishText([selectedNotification.summary, selectedNotification.body].filter(Boolean).join("\n\n"), qsTr("Notification copied"));
    }
    function openSettings(): void {
        navigationInteracted(); detailsClosing(); viewMemory.synchronize();
        if (!settingsOpen) messageWasOpen = detailsOpen;
        settingsOpen = true; detailsOpen = true;
        focusDetailsRequested();
    }
    function closeDetails(): void {
        detailsClosing(); viewMemory.synchronize();
        if (settingsOpen) {
            settingsOpen = false;
            detailsOpen = messageWasOpen && hasSelection;
            focusSearchRequested();
        } else detailsOpen = false;
    }
    function openNotifications(key: string, requestedTab: string, origin: string): void {
        returnSurface = origin;
        settingsOpen = false;
        if (key) { filterText = ""; pendingGroupKey = key; Qt.callLater(resolveGroup); }
    }
    function resolveGroup(): void {
        if (!pendingGroupKey || !notificationState.backend.ready) return;
        notificationState.backend.queryCenter({view: "app", query: "", group_key: pendingGroupKey},
            {resolve: true, entryGeneration: entryGeneration, group: pendingGroupKey});
    }
    function goBack(): void { if (returnSurface === "activity") backRequested(); else closeWindowRequested(); }
    function dismissNavigation(): bool { if (detailsOpen) closeDetails(); else goBack(); return true; }
    function refresh(): void { notificationState.backend.snapshot(); catalog.refresh(); }
    function captureScreenshot(x: real, y: real, width: real, height: real): bool { return screenshotCapture.captureRegion(x, y, width, height); }
    function activateUi(workspaceId): void { activateUiState(workspaceId); nowMs = Date.now(); Qt.callLater(resolveGroup); }
    function deactivateUi(): void { rememberApp(); deactivateUiState(); entryGeneration++; returnSurface = ""; }
    signal replyFocusRequested
    signal backRequested
    Connections {
        target: controller.notificationState
        function onCenterResponse(context: var, value: var, error: string, code: string): void {
            if (!context.resolve || context.entryGeneration !== controller.entryGeneration || context.group !== controller.pendingGroupKey) return;
            controller.pendingGroupKey = "";
            if (error || !value?.app_key) { controller.catalog.detailError = error || qsTr("Notification group unavailable"); return; }
            controller.pendingAppKey = value.app_key;
            controller.catalog.revealKey = value.app_key;
            controller.catalog.reloadApps();
        }
    }
    Connections {
        target: controller.notificationState.backend
        function onReadyChanged(): void { if (controller.notificationState.backend.ready) controller.resolveGroup(); }
    }
    Io.ClipboardPublisher { id: clipboard; onFinished: function (succeeded, message) { controller.copyStatus = message; } }
    Io.ClipboardScreenshotCapture { id: screenshotCapture; active: controller.uiActive; startMessage: "Capturing Notifications panel…" }
    Core.SerializedListModel { id: records }
    Timer { interval: 30000; repeat: true; running: controller.uiActive; onTriggered: controller.nowMs = Date.now() }
}
