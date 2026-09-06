import QtQuick
import Shelllist.Ui as Ui

// Shared by Activity and the notification callout. Drafts and history outlive views.
Item {
    id: notificationState

    property bool uiActive: false
    property bool historyEnabled: false
    property var notifications: ({ available: false, count: 0, dnd: false })
    property var notificationActive: ({ available: false, notifications: [] })
    property var history: []
    property bool historyLoading: false
    property bool historyHasMore: false
    property bool historyLoaded: false
    property bool historyDirty: false
    property string lastError: ""
    property string historyError: ""
    property var drafts: ({})
    property var replies: ({})
    property var expandedGroups: ({})
    readonly property var activeNotifications: notificationActive.notifications || []
    readonly property var activeGroups: Ui.NotificationPresentation.groupRecords(
        Ui.NotificationPresentation.newestFirst(activeNotifications))
    readonly property int draftCount: Object.keys(drafts).filter(function (key) {
        return String(notificationState.drafts[key] || "").length > 0;
    }).length
    property NotificationBackend backend: notificationBackend

    function applySnapshot(snapshot: var): void {
        if (snapshot.notifications)
            notifications = snapshot.notifications;
        if (snapshot.notification_active)
            notificationActive = snapshot.notification_active;
    }
    function isActive(id: int): bool {
        return activeNotifications.some(function (notification) { return notification.id === id; });
    }
    function isGroupActive(key: string): bool {
        return activeNotifications.some(function (notification) {
            return Ui.NotificationPresentation.groupKey(notification) === key;
        });
    }
    function setExpanded(key: string, expanded: bool): void {
        const next = Object.assign(Object.create(null), expandedGroups);
        next[key] = expanded;
        expandedGroups = next;
    }
    function setDraft(id: int, text: string): void {
        const next = Object.assign({}, drafts);
        if (text.length > 0)
            next[id] = text;
        else
            delete next[id];
        drafts = next;
    }
    function setReplyState(id: int, pending: bool, error: string): void {
        const next = Object.assign({}, replies);
        next[id] = { pending: pending, error: error };
        replies = next;
    }
    function finishReply(id: int, sentText: string, error: string): void {
        setReplyState(id, false, error);
        if (!error && String(drafts[id] || "").trim() === sentText)
            setDraft(id, "");
    }
    function replyNotification(id: int, text: string): bool {
        const value = text.trim();
        if (!value || (replies[id] && replies[id].pending))
            return false;
        if (!isActive(id)) {
            setReplyState(id, false, "Notification is no longer active. Draft retained.");
            return false;
        }
        setDraft(id, text);
        setReplyState(id, true, "");
        return backend.reply(id, value);
    }
    function scheduleHistory(): void {
        historyDirty = true;
        if (historyEnabled)
            historyDebounce.restart();
    }
    function reloadHistory(): void {
        if (historyLoading) {
            historyDirty = true;
            return;
        }
        historyDirty = false;
        historyError = "";
        historyLoading = true;
        backend.loadHistory(null, true);
    }
    function loadMoreHistory(): void {
        if (historyLoading || !historyHasMore || history.length === 0)
            return;
        historyError = "";
        historyLoading = true;
        backend.loadHistory(history[history.length - 1].history_id, false);
    }
    function applyHistory(records: var, refresh: bool): void {
        const values = Array.isArray(records) ? records : [];
        const hadHistory = history.length > 0;
        const overlap = values.some(function (record) {
            return notificationState.history.some(function (old) { return old.history_id === record.history_id; });
        });
        history = Ui.NotificationPresentation.mergeHistory(history, values);
        if (!refresh || !hadHistory)
            historyHasMore = values.length === 50;
        // Catch up across multiple pages when more than 50 arrived while closed.
        if (refresh && hadHistory && !overlap && values.length === 50) {
            backend.loadHistory(values[values.length - 1].history_id, true);
            return;
        }
        historyLoaded = true;
        historyLoading = false;
        if (historyDirty && historyEnabled)
            historyDebounce.restart();
    }
    function failHistory(message: string): void {
        historyLoading = false;
        historyError = message;
    }
    function setDndForMinutes(minutes: int): bool {
        return backend.setDnd(minutes > 0, minutes > 0 ? Date.now() + minutes * 60000 : null);
    }
    function dismissNotification(id: int): bool { return backend.dismiss(id); }
    function clearNotifications(): bool { return backend.clear(); }
    function clearNotificationGroup(key: string): bool { return backend.clearGroup(key); }
    function snoozeNotification(id: int, minutes: int): bool {
        return backend.snooze(id, Date.now() + minutes * 60000);
    }
    function invokeNotificationAction(id: int, key: string): bool { return backend.invoke(id, key); }

    onNotificationsChanged: scheduleHistory()
    onNotificationActiveChanged: scheduleHistory()
    onHistoryEnabledChanged: if (historyEnabled) scheduleHistory()

    Timer {
        id: historyDebounce
        interval: 120
        onTriggered: if (notificationState.historyEnabled) notificationState.reloadHistory()
    }
    NotificationBackend { id: notificationBackend; store: notificationState }
}
