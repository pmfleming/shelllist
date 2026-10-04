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
    active: store.resident || store.uiActive || requestRunning

    function request(prefix: string, method: string, params: var, context: var): bool {
        const id = nextRequestId(prefix);
        const next = Object.assign({}, requests);
        next[id] = Object.assign({generation: store.dataGeneration, eventVersion: store.eventVersion}, context || ({}));
        requests = next;
        return call(id, method, params);
    }
    function snapshot(): void {
        if (!Object.keys(requests).some(id => id.startsWith("snapshot-")))
            request("snapshot", Api.methods.snapshot, {}, {snapshot: true});
    }
    function loadHistory(cursor: var, refresh: bool): bool {
        return request("history", Api.methods.notificationsQueryHistory, {
            query: store.historyQuery,
            cursor: cursor,
            anchor: refresh ? store.historyAnchor : null,
            limit: 50
        }, {
            history: true,
            historyGeneration: store.historyGeneration,
            historyRevision: store.observedHistoryRevision,
            cursor: cursor,
            refresh: refresh
        });
    }
    function setDnd(enabled: bool, until: var): bool {
        return request("dnd", Api.methods.notificationsSetDnd, {
            enabled: enabled,
            until_unix_ms: until
        }, {dnd: true});
    }
    function dismiss(id: int): bool {
        return request("dismiss", Api.methods.notificationsDismiss, {
            id: id
        }, {operationKey: store.keyFor(id)});
    }
    function clear(): bool {
        return request("clear", Api.methods.notificationsClear, {}, {});
    }
    function clearGroup(key: string): bool {
        return request("clear-group", Api.methods.notificationsClearGroup, {
            group_key: key
        }, {});
    }
    function snooze(id: int, until: double): bool {
        return request("snooze", Api.methods.notificationsSnooze, {
            id: id,
            until_unix_ms: until
        }, {operationKey: store.keyFor(id)});
    }
    function invoke(id: int, key: string): bool {
        return request("action", Api.methods.notificationsInvokeAction, {
            id: id,
            action_key: key,
            activation_token: null
        }, {operationKey: store.keyFor(id)});
    }
    function reply(id: int, text: string): bool {
        return request("reply", Api.methods.notificationsReply, {
            id: id,
            text: text
        }, {
            replyKey: store.keyFor(id),
            text: text
        });
    }
    function finish(id: string, data: var, error: string, errorCode: string): void {
        const context = requests[id];
        if (!context)
            return;
        const next = Object.assign({}, requests);
        delete next[id];
        requests = next;
        if ((context.generation !== undefined && context.generation !== store.dataGeneration) || (context.history && context.historyGeneration !== undefined && context.historyGeneration !== store.historyGeneration))
            return;
        store.flushEvents();
        if (context.replyKey !== undefined)
            store.finishReply(context.replyKey, context.text, error);
        if (context.dnd)
            store.finishDnd(context.eventVersion === store.eventVersion ? data.notifications : null, error);
        if (context.operationKey !== undefined)
            store.finishOperation(context.operationKey);
        if (error) {
            if (context.history && errorCode === "history-cursor-stale")
                store.invalidateHistory();
            else if (context.history)
                store.failHistory(error);
            else
                store.lastError = error;
            return;
        }
        if (!context.history && !context.snapshot)
            store.lastError = "";
        if (data.snapshot) {
            if (context.eventVersion === store.eventVersion)
                store.applySnapshot(data.snapshot);
            else if (!store.notifications.available && (store.resident || store.uiActive))
                Qt.callLater(snapshot);
        }
        if (context.history) {
            if (context.historyRevision !== undefined && context.historyRevision !== store.observedHistoryRevision) {
                store.invalidateHistory();
            } else {
                store.applyHistory(data.notification_page, context.refresh, context.cursor);
            }
        }
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope && envelope.data ? envelope.data : ({}), responseError(envelope, transportError, "Notification operation failed"), envelope && envelope.error ? envelope.error.code : "");
    }
    onSendFailed: function (id, message) {
        finish(id, {}, message, "");
    }
    onTransportFailed: function (message, lostRequestIds) {
        lostRequestIds.forEach(function (id) {
            backend.finish(id, {}, message, "");
        });
        store.connectionLost();
    }
    onTransportReady: {
        if (store.resident || store.uiActive)
            snapshot();
        if (store.historyDirty || !store.historyLoaded)
            store.scheduleHistory();
    }
    onEventGapDetected: {
        snapshot();
        store.scheduleHistory();
    }
    Connections {
        target: backend.store
        function onUiActiveChanged(): void {
            if (backend.store.uiActive && backend.ready && !backend.store.resident)
                backend.snapshot();
        }
        function onResidentChanged(): void {
            if (backend.store.resident && backend.ready)
                backend.snapshot();
        }
    }
    onEventReceived: function (event) {
        if (event.stream === Api.streams.notifications)
            store.queueEvent(true, event.data);
        else if (event.stream === Api.streams.notificationActive)
            store.queueEvent(false, event.data);
    }
}
