import QtQuick
import Shelllist.Io as Io
import "ActivityApi.js" as Api

Io.DaemonBackend {
    id: backend
    // The owner constructs this adapter; avoid a circular composite-type dependency.
    required property var store
    property var requests: ({})

    daemonName: "bar-daemon"
    expectedProtocol: Api.protocol
    expectedVersion: Api.version
    streams: [Api.streams.notifications, Api.streams.notificationActive]
    // Keep the command consumer alive until replies are acknowledged, even on close.
    active: store.uiActive || requestRunning

    function request(prefix: string, method: string, params: var, context: var): bool {
        const id = nextRequestId(prefix);
        const next = Object.assign({}, requests);
        next[id] = context || ({});
        requests = next;
        return call(id, method, params);
    }
    function snapshot(): void { request("snapshot", Api.methods.snapshot, {}, {}); }
    function loadHistory(cursor: var, refresh: bool): bool {
        return request("history", Api.methods.notificationsList,
            { before_history_id: cursor, limit: 50 }, { history: true, refresh: refresh });
    }
    function setDnd(enabled: bool, until: var): bool {
        return request("dnd", Api.methods.notificationsSetDnd,
            { enabled: enabled, until_unix_ms: until }, {});
    }
    function dismiss(id: int): bool {
        return request("dismiss", Api.methods.notificationsDismiss, { id: id }, {});
    }
    function clear(): bool { return request("clear", Api.methods.notificationsClear, {}, {}); }
    function clearGroup(key: string): bool {
        return request("clear-group", Api.methods.notificationsClearGroup, { group_key: key }, {});
    }
    function snooze(id: int, until: double): bool {
        return request("snooze", Api.methods.notificationsSnooze,
            { id: id, until_unix_ms: until }, {});
    }
    function invoke(id: int, key: string): bool {
        return request("action", Api.methods.notificationsInvokeAction,
            { id: id, action_key: key, activation_token: null }, {});
    }
    function reply(id: int, text: string): bool {
        return request("reply", Api.methods.notificationsReply, { id: id, text: text },
            { replyId: id, text: text });
    }
    function finish(id: string, data: var, error: string): void {
        const context = requests[id];
        if (!context)
            return;
        const next = Object.assign({}, requests);
        delete next[id];
        requests = next;
        if (context.replyId !== undefined)
            store.finishReply(context.replyId, context.text, error);
        if (error) {
            store.lastError = error;
            if (context.history)
                store.failHistory(error);
            return;
        }
        store.lastError = "";
        if (data.snapshot)
            store.applySnapshot(data.snapshot);
        if (context.history)
            store.applyHistory(data.notification_history || [], context.refresh);
        else if (!id.startsWith("snapshot"))
            store.scheduleHistory();
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope && envelope.data ? envelope.data : ({}), responseError(envelope, transportError,
            "Notification operation failed"));
    }
    onSendFailed: function (id, message) { finish(id, {}, message); }
    onTransportFailed: function (message, lostRequestIds) {
        lostRequestIds.forEach(function (id) { backend.finish(id, {}, message); });
    }
    onTransportReady: if (store.uiActive) snapshot()
    onEventGapDetected: { snapshot(); store.scheduleHistory(); }
    Connections {
        target: backend.store
        function onUiActiveChanged(): void {
            if (backend.store.uiActive && backend.ready) backend.snapshot();
        }
    }
    onEventReceived: function (event) {
        if (event.stream === Api.streams.notifications)
            store.notifications = event.data;
        else if (event.stream === Api.streams.notificationActive)
            store.notificationActive = event.data;
    }
}
