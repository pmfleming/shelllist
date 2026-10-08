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
    function queryCenter(params: var, context: var): bool {
        return request("center", Api.methods.notificationsQueryCenter, params, {center: context});
    }
    function setDnd(enabled: bool, until: var): bool {
        return request("dnd", Api.methods.notificationsSetDnd, {
            enabled: enabled,
            until_unix_ms: until
        }, {dnd: true});
    }
    function setAppPolicy(key: string, policy: var): bool {
        return request("app-policy", Api.methods.notificationsSetAppPolicy, {app_key: key, policy: policy}, {policyKey: key});
    }
    function prepareDelete(key: var, selected: var, generation: int): bool {
        return request("prepare-delete", Api.methods.notificationsPrepareDelete, {app_key: key, selected: selected}, {deleteGeneration: generation});
    }
    function deleteConfirmed(token: string, cancel: bool): bool {
        return request("delete", Api.methods.notificationsDelete, {token: token, cancel: cancel}, {deleteOperation: !cancel, cancelDelete: cancel});
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
        // Consume once, then fence late completions before touching current state.
        if (context.generation !== store.dataGeneration)
            return;
        store.flushEvents();
        if (context.center) {
            store.centerResponse(context.center, data.notification_center, error, errorCode);
            return;
        }
        if (context.policyKey !== undefined) {
            const policyError = error || (!data.notifications?.app_policies?.[context.policyKey] ? qsTr("Invalid application policy acknowledgement") : "");
            store.finishAppPolicy(context.policyKey, data.notifications, policyError);
            store.lastError = policyError;
            return;
        }
        if (context.deleteGeneration !== undefined) { store.finishPrepareDelete(context.deleteGeneration, data.delete_confirmation, error); return; }
        if (context.cancelDelete) return;
        if (context.deleteOperation) { store.finishDelete(error || (!Number.isSafeInteger(data.deleted) || data.deleted < 0 || data.deleted > 100200 ? qsTr("Invalid deletion acknowledgement. Refresh before retrying.") : "")); return; }
        if (context.replyKey !== undefined)
            store.finishReply(context.replyKey, context.text, error);
        if (context.dnd)
            store.finishDnd(context.eventVersion === store.eventVersion ? data.notifications : null, error);
        if (context.operationKey !== undefined)
            store.finishOperation(context.operationKey);
        if (error) {
            store.lastError = error;
            return;
        }
        if (!context.snapshot)
            store.lastError = "";
        if (!data.snapshot)
            return;
        if (context.eventVersion === store.eventVersion)
            store.applySnapshot(data.snapshot);
        else if (!store.notifications.available && (store.resident || store.uiActive))
            Qt.callLater(snapshot);
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
    }
    onEventGapDetected: snapshot()
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
