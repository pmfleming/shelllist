import QtQuick
import Shelllist.Io as Io
import "ActivityApi.js" as Api

Io.BarDaemonBackend {
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
        next[id] = Object.assign({kind: prefix, generation: store.dataGeneration, eventVersion: store.eventVersion}, context || ({}));
        requests = next;
        return call(id, method, params);
    }
    function snapshot(): void {
        if (!snapshotPending() && !Object.keys(requests).some(id => id.startsWith("snapshot-")))
            request("snapshot", Api.methods.snapshot, {}, {});
    }
    function queryCenter(params: var, context: var): bool {
        return request("center", Api.methods.notificationsQueryCenter, params, {center: context});
    }
    function snoozeSharing(generation: double, minutes: int): bool {
        return request("sharing", Api.methods.notificationsSnoozeSharing, {generation: generation, minutes: minutes}, {sharingGeneration: generation});
    }
    function setSettings(patch: var): bool {
        return request("settings", Api.methods.notificationsSetSettings, patch, {});
    }
    function setReading(monitor: string, reading: bool): bool {
        if (Object.values(requests).some(context => context.kind === "reading" && context.monitor === monitor))
            return false;
        return request("reading", Api.methods.notificationsSetReading, {monitor: monitor, reading: reading}, {monitor: monitor});
    }
    function setDnd(enabled: bool, until: var): bool {
        return request("dnd", Api.methods.notificationsSetDnd, {
            enabled: enabled,
            until_unix_ms: until
        }, {});
    }
    function setAppPolicy(key: string, policy: var): bool {
        return request("app-policy", Api.methods.notificationsSetAppPolicy, {app_key: key, policy: policy}, {policyKey: key});
    }
    function prepareDelete(key: var, selected: var, generation: int): bool {
        return request("prepare-delete", Api.methods.notificationsPrepareDelete, {app_key: key, selected: selected}, {deleteGeneration: generation});
    }
    function deleteConfirmed(token: string, cancel: bool): bool {
        return request("delete", Api.methods.notificationsDelete, {token: token, cancel: cancel}, {cancelDelete: cancel});
    }
    function dismiss(id: int): bool {
        return request("dismiss", Api.methods.notificationsDismiss, {
            id: id
        }, {operationKey: store.keyFor(id)});
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
    function contextAction(record: var, key: string): bool {
        return request("context-action", Api.methods.notificationsContextAction, {
            id: record.id, created_unix_ms: record.created_unix_ms, updated_unix_ms: record.updated_unix_ms, key: key
        }, {operationKey: store.keyFor(record), updated: record.updated_unix_ms, actionKey: key});
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
        // Queued observations precede domain acknowledgement. Ownership is
        // already retired, so a reentrant completion cannot publish twice.
        store.flushEvents();
        acknowledge(context, data, error, errorCode);
    }
    function acknowledge(context: var, data: var, error: string, errorCode: string): void {
        // Scoped readers/settings/consent own their result, including errors.
        // They must not fall through to generic snapshot or error publication.
        switch (context.kind) {
        case "sharing":
            acknowledgeSharing(context, data, error); return;
        case "context-action":
            acknowledgeContextAction(context, data, error); return;
        case "settings":
            acknowledgeSettings(context, data, error); return;
        case "reading":
            return; // Lease failure expires safely in Rust; never replay mutations.
        case "center":
            store.centerResponse(context.center, data.notification_center, error, errorCode);
            return;
        case "app-policy":
            acknowledgeAppPolicy(context, data, error); return;
        case "prepare-delete":
            store.finishPrepareDelete(context.deleteGeneration, data.delete_confirmation, error);
            return;
        case "delete":
            if (!context.cancelDelete)
                store.finishDelete(error || (!NotificationValidation.integerIn(data.deleted, 0, 100200) ? qsTr("Invalid deletion acknowledgement. Refresh before retrying.") : ""));
            return;
        default:
            acknowledgeOperation(context, data, error);
        }
    }
    function currentNotifications(context: var, data: var): var {
        return context.eventVersion === store.eventVersion ? data.notifications : null;
    }
    function acknowledgeSharing(context: var, data: var, error: string): void {
        const failure = error || (data.notifications?.sharing?.generation !== context.sharingGeneration ? qsTr("Screen-sharing acknowledgement changed") : "");
        store.finishSharing(currentNotifications(context, data), failure);
    }
    function acknowledgeContextAction(context: var, data: var, error: string): void {
        const failure = error || (typeof data.copied !== "boolean" ? qsTr("Notification action outcome unconfirmed") : "");
        store.finishOperation(context.operationKey);
        store.lastError = failure;
        store.contextActionFinished(context.operationKey, context.updated, context.actionKey, !failure && data.copied === true, failure);
    }
    function acknowledgeSettings(context: var, data: var, error: string): void {
        const failure = error || (!NotificationValidation.settings(data.notifications?.settings) ? qsTr("Invalid notification settings acknowledgement") : "");
        store.finishSettings(currentNotifications(context, data), failure);
    }
    function acknowledgeAppPolicy(context: var, data: var, error: string): void {
        const failure = error || (!data.notifications?.app_policies?.[context.policyKey] ? qsTr("Invalid application policy acknowledgement") : "");
        store.finishAppPolicy(context.policyKey, data.notifications, failure);
        store.lastError = failure;
    }
    function acknowledgeOperation(context: var, data: var, error: string): void {
        if (context.replyKey !== undefined)
            store.finishReply(context.replyKey, context.text, error);
        if (context.kind === "dnd")
            store.finishDnd(currentNotifications(context, data), error);
        if (context.operationKey !== undefined)
            store.finishOperation(context.operationKey);
        if (error) {
            store.lastError = error;
            return;
        }
        if (context.kind !== "snapshot")
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
