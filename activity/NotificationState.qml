import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

// One notification store for the bar, toasts and panel. Transport ownership and
// persisted data belong to the daemon; cached closed rows only bridge history IO.
Item {
    id: notificationState
    property bool resident: false
    property bool uiActive: false
    property bool historyEnabled: uiActive
    property int dataGeneration: 0
    property int eventVersion: 0
    property double acceptedHistoryRevision: -1
    property double acceptedActiveRevision: -1
    property double observedHistoryRevision: -1
    property var queuedSummary: null
    property var queuedActive: null
    property int dndDurationMinutes: 30
    property bool dndPending: false
    property string dndError: ""
    property var dndRequest: null
    property var notifications: ({available: false, count: 0, dnd: false})
    property var notificationActive: ({available: false, notifications: []})
    property var activeRecords: []
    property var retiredRecords: []
    property var history: []
    property bool historyLoading: false
    property bool historyHasMore: false
    property bool historyLoaded: false
    property bool historyDirty: false
    property string lastError: ""
    property string historyError: ""
    readonly property alias drafts: replyDrafts.drafts
    property var replies: ({})
    property var operations: ({})
    readonly property var activeNotifications: activeRecords
    readonly property var recentNotifications: Ui.NotificationPresentation.recentRecords(activeRecords.concat(retiredRecords), history)
    readonly property int draftCount: Object.keys(drafts).filter(key => String(drafts[key] || "").length > 0).length
    property NotificationBackend backend: notificationBackend

    function equal(left: var, right: var): bool { return JSON.stringify(left) === JSON.stringify(right); }
    function applySummary(value: var): void {
        if (!value || (value.history_revision !== undefined && Number(value.history_revision) < acceptedHistoryRevision))
            return;
        acceptedHistoryRevision = Number(value.history_revision ?? -1);
        if (!equal(notifications, value))
            notifications = value;
    }
    function applyActive(value: var): void {
        if (!value || (value.revision !== undefined && Number(value.revision) < acceptedActiveRevision))
            return;
        acceptedActiveRevision = Number(value.revision ?? -1);
        if (!equal(notificationActive, value))
            notificationActive = value;
    }
    function applySnapshot(snapshot: var): void {
        applySummary(snapshot.notifications);
        applyActive(snapshot.notification_active);
    }
    function queueEvent(summary: bool, value: var): void {
        eventVersion++;
        if (summary) queuedSummary = value;
        else queuedActive = value;
        Qt.callLater(flushEvents);
    }
    function flushEvents(): void {
        const summary = queuedSummary;
        const active = queuedActive;
        queuedSummary = null;
        queuedActive = null;
        applySummary(summary);
        applyActive(active);
    }
    function connectionLost(): void {
        dataGeneration++;
        queuedSummary = null;
        queuedActive = null;
        acceptedHistoryRevision = -1;
        acceptedActiveRevision = -1;
        observedHistoryRevision = -1;
        historyLoading = false;
        historyDirty = true;
        historyDebounce.stop();
        notifications = Object.assign({}, notifications, {available: false});
        notificationActive = Object.assign({}, notificationActive, {available: false});
    }
    function reconcileActive(): void {
        // Popup visibility changes must not reserialize/repaint center rows.
        const next = (notificationActive.notifications || []).map(function (record) {
            const value = Object.assign({}, record);
            delete value.toast_visible;
            delete value.toast_expires_unix_ms;
            return value;
        });
        const keys = new Set(next.map(Ui.NotificationPresentation.recordKey));
        const transientKeys = new Set(next.filter(record => (record.hints || {}).transient).map(Ui.NotificationPresentation.recordKey));
        // Replacing a persisted notification with a transient one also deletes
        // its persisted row; mirror that removal rather than retaining a ghost.
        const retainedHistory = history.filter(record => !transientKeys.has(Ui.NotificationPresentation.recordKey(record)));
        if (!equal(history, retainedHistory)) history = retainedHistory;
        const retired = Ui.NotificationPresentation.recentRecords(activeRecords.filter(record => !keys.has(Ui.NotificationPresentation.recordKey(record)) && !(record.hints || {}).transient), retiredRecords).filter(record => !keys.has(Ui.NotificationPresentation.recordKey(record))).slice(0, 200);
        if (!equal(retiredRecords, retired)) retiredRecords = retired;
        if (!equal(activeRecords, next)) activeRecords = next;
    }
    function keyFor(value: var): string {
        if (typeof value === "string" && value.includes(":")) return value;
        if (value && typeof value === "object") return Ui.NotificationPresentation.recordKey(value);
        const record = activeRecords.find(item => item.id === Number(value));
        return record ? Ui.NotificationPresentation.recordKey(record) : "unavailable:" + value;
    }
    function isActive(id: int): bool {
        return notifications.available && notificationActive.available !== false && activeRecords.some(record => record.id === id);
    }
    function isLive(record: var): bool {
        const key = keyFor(record);
        return notifications.available && notificationActive.available !== false && activeRecords.some(item => keyFor(item) === key);
    }
    function setDraft(key: var, text: string): void { replyDrafts.put(keyFor(key), text); }
    function setReplyState(key: var, pending: bool, error: string): void {
        replies = Object.assign({}, replies, {[keyFor(key)]: {pending: pending, error: error}});
    }
    function finishReply(key: var, sentText: string, error: string): void {
        const identity = keyFor(key);
        setReplyState(identity, false, error);
        if (!error && String(drafts[identity] || "").trim() === sentText)
            setDraft(identity, "");
    }
    function replyNotification(key: var, text: string): bool {
        const identity = keyFor(key);
        const value = text.trim();
        if (!value || replies[identity]?.pending)
            return false;
        const record = activeRecords.find(item => keyFor(item) === identity);
        if (!record || !isLive(record) || !Ui.NotificationPresentation.replyAction(record)) {
            setReplyState(identity, false, "Notification cannot accept an inline reply. Draft retained.");
            return false;
        }
        setDraft(identity, text);
        setReplyState(identity, true, "");
        return backend.reply(record.id, value);
    }
    function scheduleHistory(): void {
        historyDirty = true;
        if (historyEnabled && !historyLoading && backend.ready)
            historyDebounce.restart();
    }
    function reloadHistory(): void {
        historyDebounce.stop();
        if (historyLoading)
            return;
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
        const overlap = values.some(record => history.some(old => old.history_id === record.history_id));
        const merged = Ui.NotificationPresentation.mergeHistory(history, values);
        if (!equal(history, merged)) history = merged;
        const received = new Set(values.map(Ui.NotificationPresentation.recordKey));
        const retained = retiredRecords.filter(record => !received.has(Ui.NotificationPresentation.recordKey(record)));
        if (!equal(retiredRecords, retained)) retiredRecords = retained;
        if (!refresh || !hadHistory)
            historyHasMore = values.length === 50;
        if (refresh && hadHistory && !overlap && values.length === 50) {
            backend.loadHistory(values[values.length - 1].history_id, true);
            return;
        }
        historyLoaded = true;
        historyLoading = false;
        if (historyDirty) scheduleHistory();
    }
    function failHistory(message: string): void {
        historyLoading = false;
        historyError = message;
    }
    function setDndEnabled(enabled: bool): bool {
        if (dndPending) return false;
        dndRequest = {enabled: enabled, minutes: dndDurationMinutes};
        dndError = "";
        dndPending = true;
        return backend.setDnd(enabled, enabled && dndDurationMinutes > 0 ? Date.now() + dndDurationMinutes * 60000 : null);
    }
    function finishDnd(state: var, error: string): void {
        dndPending = false;
        dndError = error;
        if (!error) applySummary(state);
    }
    function retryDnd(): void {
        if (dndRequest && !dndPending) {
            dndDurationMinutes = dndRequest.minutes;
            setDndEnabled(dndRequest.enabled);
        }
    }
    function setDndDuration(minutes: int): void {
        if (dndPending || ![0, 30, 60].includes(minutes) || minutes === dndDurationMinutes) return;
        dndDurationMinutes = minutes;
        if (notifications.dnd) setDndEnabled(true);
    }
    function beginOperation(id: int): bool {
        const key = keyFor(id);
        if (!isActive(id) || operations[key]) return false;
        operations = Object.assign({}, operations, {[key]: true});
        lastError = "";
        return true;
    }
    function finishOperation(key: string): void {
        const next = Object.assign({}, operations);
        delete next[key];
        operations = next;
    }
    function dismissNotification(id: int): bool { return beginOperation(id) && backend.dismiss(id); }
    function clearNotifications(): bool { return backend.clear(); }
    function clearNotificationGroup(key: string): bool { return backend.clearGroup(key); }
    function snoozeNotification(id: int, minutes: int): bool { return beginOperation(id) && backend.snooze(id, Date.now() + minutes * 60000); }
    function invokeNotificationAction(id: int, key: string): bool {
        const record = activeRecords.find(item => item.id === id);
        return !!record && Ui.NotificationPresentation.notificationActions(record).some(action => action.key === key && !Ui.NotificationPresentation.isReplyAction(action)) && beginOperation(id) && backend.invoke(id, key);
    }

    onNotificationActiveChanged: reconcileActive()
    onNotificationsChanged: {
        const revision = Number(notifications.history_revision ?? -1);
        if (revision !== observedHistoryRevision || !historyLoaded) {
            observedHistoryRevision = revision;
            scheduleHistory();
        }
    }
    onHistoryEnabledChanged: if (historyEnabled && (!historyLoaded || historyDirty)) scheduleHistory()
    Timer {
        id: historyDebounce
        interval: 120
        onTriggered: if (notificationState.historyEnabled && notificationState.backend.ready) notificationState.reloadHistory()
    }
    NotificationBackend { id: notificationBackend; store: notificationState }
    Core.DraftStore { id: replyDrafts }
}
