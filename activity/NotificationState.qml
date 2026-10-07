import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui

// One notification store for the bar, toasts and panel. Transport ownership and
// catalog identity, search, ordering and snapshot consistency belong to Rust.
Item {
    id: notificationState
    property bool resident: false
    property bool uiActive: false
    property int dataGeneration: 0
    property int eventVersion: 0
    property double acceptedHistoryRevision: -1
    property double acceptedActiveRevision: -1
    readonly property double observedHistoryRevision: Number(notifications.history_revision ?? -1)
    property var queuedSummary: null
    property var queuedActive: null
    property int dndDurationMinutes: 30
    property bool dndPending: false
    property string dndError: ""
    property var dndRequest: null
    property var notifications: ({available: false, count: 0, dnd: false})
    property var notificationActive: ({available: false, notifications: []})
    property var activeRecords: []
    property string lastError: ""
    readonly property alias drafts: replyDrafts.drafts
    property var replies: ({})
    property var operations: ({})
    readonly property var activeNotifications: activeRecords
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
        queuedSummary = null;
        queuedActive = null;
        acceptedHistoryRevision = -1;
        acceptedActiveRevision = -1;
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
    NotificationBackend { id: notificationBackend; store: notificationState }
    Core.DraftStore { id: replyDrafts }
}
