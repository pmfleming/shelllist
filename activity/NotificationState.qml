import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

// One notification store for the bar, toasts and panel. Transport ownership and
// catalog identity, search, ordering and snapshot consistency belong to Rust.
Item {
    id: notificationState
    property bool resident: false
    property bool uiActive: false
    // Legacy message-window reader remains available for protocol consumers;
    // the panel uses bounded native app/detail projections instead.
    property bool historyEnabled: false
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
    // Only the requested visible window. Refresh pages are staged atomically;
    // the old window remains visible until a complete authoritative replacement.
    property var history: []
    property string historyQuery: ""
    property int historyGeneration: 0
    property var historyCursor: null
    property string historyEpoch: ""
    property string historyRevision: ""
    property var historyStaging: []
    property string stagingEpoch: ""
    property string stagingRevision: ""
    property var historyAnchor: null
    property bool historyLoading: false
    readonly property bool historyHasMore: historyCursor !== null
    property bool historyLoaded: false
    property bool historyDirty: false
    property string lastError: ""
    property string historyError: ""
    readonly property alias drafts: replyDrafts.drafts
    property var replies: ({})
    property var operations: ({})
    readonly property var activeNotifications: activeRecords
    readonly property var recentNotifications: history
    readonly property int draftCount: Object.keys(drafts).filter(key => String(drafts[key] || "").length > 0).length
    property NotificationBackend backend: notificationBackend
    signal centerResponse(var context, var value, string error, string code)

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
        resetHistoryRead();
        queuedSummary = null;
        queuedActive = null;
        acceptedHistoryRevision = -1;
        acceptedActiveRevision = -1;
        observedHistoryRevision = -1;
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
    function setHistoryQuery(value: string): void {
        const query = value.trim().toLowerCase();
        if (historyQuery === query) return;
        historyQuery = query;
        // These are bounded ordinary RPCs, not cancellable subscriptions.
        // Let old reads finish; their generation cannot alter the new query.
        resetHistoryRead();
        historyLoaded = false;
        history = [];
        scheduleHistory();
    }
    function scheduleHistory(): void {
        historyDirty = true;
        if (historyEnabled && !historyLoading && backend.ready && !historyDebounce.running)
            historyDebounce.start();
    }
    function reloadHistory(): void {
        historyDebounce.stop();
        if (historyLoading) return;
        historyGeneration++;
        historyDirty = false;
        historyError = "";
        historyStaging = [];
        stagingEpoch = "";
        stagingRevision = "";
        const oldest = history.length ? Ui.NotificationPresentation.notificationFor(history[history.length - 1]) : null;
        historyAnchor = oldest ? {created: oldest.created_unix_ms, id: oldest.id} : null;
        historyLoading = true;
        backend.loadHistory(null, true);
    }
    function loadMoreHistory(): void {
        if (historyLoading || !historyHasMore) return;
        if (historyDirty) { reloadHistory(); return; }
        historyError = "";
        historyLoading = true;
        backend.loadHistory(historyCursor, false);
    }
    function resetHistoryRead(): void {
        historyGeneration++;
        historyLoading = false;
        historyStaging = [];
        historyCursor = null;
    }
    function invalidateHistory(): void {
        resetHistoryRead();
        scheduleHistory(); // Read-only recovery; never replay a mutation.
    }
    function historyToken(value: var): bool { return typeof value === "string" && value.length > 0; }
    function validHistoryPage(page: var): bool {
        return Array.isArray(page?.records) && page.records.length <= 100
            && historyToken(page.epoch) && historyToken(page.revision)
            && page.query === historyQuery && typeof page.anchor_reached === "boolean"
            && (page.next_cursor === null || historyToken(page.next_cursor));
    }
    function historyPageAdvances(page: var, base: var, requestedCursor: var): bool {
        if (base.length + page.records.length > 5200 || (page.next_cursor !== null && (!page.records.length || page.next_cursor === requestedCursor)))
            return false;
        const keys = new Set(base.map(Ui.NotificationPresentation.recordKey));
        return page.records.every(function (record) {
            const notification = record?.notification;
            if (!Number.isSafeInteger(notification?.id) || notification.id <= 0 || notification.id > 4294967295 || !Number.isSafeInteger(notification.created_unix_ms) || notification.created_unix_ms <= 0) return false;
            const key = Ui.NotificationPresentation.recordKey(record);
            if (keys.has(key)) return false;
            keys.add(key);
            return true;
        });
    }
    function applyHistory(page: var, refresh: bool, requestedCursor: var): void {
        if (!validHistoryPage(page)) {
            failHistory("Invalid notification history page");
            return;
        }
        const base = refresh ? historyStaging : history;
        const epoch = refresh ? stagingEpoch : historyEpoch;
        const revision = refresh ? stagingRevision : historyRevision;
        if (epoch && (epoch !== page.epoch || revision !== page.revision)) {
            invalidateHistory();
            return;
        }
        if (!historyPageAdvances(page, base, requestedCursor)) {
            failHistory("Notification history page did not advance");
            return;
        }
        const next = base.concat(page.records);
        if (refresh && page.next_cursor !== null && !page.anchor_reached) {
            stagingEpoch = page.epoch;
            stagingRevision = page.revision;
            historyStaging = next;
            if (historyEnabled) backend.loadHistory(page.next_cursor, true);
            else invalidateHistory();
            return;
        }
        if (!equal(history, next)) history = next;
        historyEpoch = page.epoch;
        historyRevision = page.revision;
        historyCursor = page.next_cursor;
        historyStaging = [];
        historyLoaded = true;
        historyLoading = false;
        if (historyDirty) scheduleHistory();
    }
    function failHistory(message: string): void {
        historyLoading = false;
        historyStaging = [];
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
