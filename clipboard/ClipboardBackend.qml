import Shelllist.Core as Core
import Shelllist.Io as Io
import "ClipApi.js" as ClipApi

Io.DaemonBackend {
    required property ClipboardController controller
    daemonName: "clip-daemon"
    expectedProtocol: "clip-api"
    expectedVersion: 1
    streams: [ClipApi.streams.history, ClipApi.streams.current, ClipApi.streams.operation,
        ClipApi.streams.capture, ClipApi.streams.session]
    active: controller.uiActive

    function finish(id: string, envelope: var, transportError: string): void {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            "clip-api", 1, daemonName, "Clipboard operation failed");
        if (error) {
            controller.handleFailure(id, error);
            return;
        }
        applyResponse(id, envelope.data || ({}));
    }

    function applyResponse(id: string, data: var): void {
        const handlers = ({
            history: function (value) { controller.applyHistory(id, value); },
            revision: function (value) { controller.applyRevision(id, value); },
            session: controller.applySession,
            entry: function (value) {
                if (id === "edit-commit") controller.detailState.applyEditCommit(value);
                else controller.detailState.applyDetails(id, value);
            },
            thumbnail: function (value) { controller.detailState.applyThumbnail(id, value); },
            operation: controller.applyOperation,
            challenge: controller.applyWipeChallenge,
            edit: function (value) { controller.detailState.applyEdit(id, value); },
            settings: controller.applySettings,
            capture: controller.applyCapture
        });
        Object.keys(data).forEach(function (key) {
            if (handlers[key]) handlers[key](data[key]);
        });
    }

    function revision(id: string): bool {
        return call(id, ClipApi.methods.historyRevision, {});
    }
    function query(id: string, text: string, generation: int, limit: int, offset: int): bool {
        return call(id, ClipApi.methods.historyQuery, {
            query: text, generation: generation, limit: limit, offset: offset || 0
        });
    }
    function details(id: string, entry: var): bool {
        return call(id, ClipApi.methods.entryDetails, { entry_id: entry.id, revision: entry.revision });
    }
    function thumbnail(id: string, entry: var): bool {
        return call(id, ClipApi.methods.entryThumbnail, { entry_id: entry.id, revision: entry.revision, edge: 640 });
    }
    function beginSession(): bool { return call("session-begin", ClipApi.methods.sessionBegin, {}); }
    function hideSession(sessionId: string): bool { return call("session-hidden", ClipApi.methods.sessionHidden, { session_id: sessionId }); }
    function endSession(sessionId: string): bool { return call("session-end", ClipApi.methods.sessionEnd, { session_id: sessionId }); }
    function action(id: string, entry: var, actionName: string, sessionId: string, fileIndex: var): bool {
        return call(id, ClipApi.methods.entryAction, {
            entry_id: entry.id, revision: entry.revision, action: actionName,
            session_id: sessionId || null, file_index: fileIndex === undefined ? null : fileIndex
        });
    }
    function beginEdit(entry: var): bool {
        return call("edit-begin", ClipApi.methods.editBegin, { entry_id: entry.id, revision: entry.revision });
    }
    function commitEdit(editId: string, value: string): bool {
        return call("edit-commit", ClipApi.methods.editCommit, { edit_id: editId, value: value });
    }
    function cancelEdit(editId: string): bool {
        return call("edit-cancel", ClipApi.methods.editCancel, { edit_id: editId });
    }
    function getSettings(): bool { return call("settings-get", ClipApi.methods.settingsGet, {}); }
    function captureScreenshot(x: int, y: int, width: int, height: int): bool {
        return call("capture-screenshot", ClipApi.methods.captureScreenshot, { x: x, y: y, width: width, height: height });
    }
    function prepareWipe(): bool { return call("wipe-prepare", ClipApi.methods.wipePrepare, {}); }
    function commitWipe(challengeId: string): bool {
        return call("wipe-commit", ClipApi.methods.wipeCommit, { challenge_id: challengeId, response: "WIPE" });
    }
    function cancelRequest(requestId: string): bool { return cancel(requestId, "cancel-" + requestId); }
    function cancelOperation(operationId: string): bool { return cancel(operationId, "cancel-operation-" + operationId); }

    onResponseReceived: function (id, envelope, transportError) { finish(id, envelope, transportError); }
    onEventReceived: function (event) {
        if (event.event === "subscribed") return;
        if (event.data && event.data.resync_required) {
            controller.handleEventGap(event.stream);
            if (event.stream === ClipApi.streams.capture)
                getSettings();
            return;
        }
        const handlers = ({});
        handlers[ClipApi.streams.history] = function () {
            controller.handleHistoryChanged(event.data
                ? event.data.history_revision : undefined);
        };
        handlers[ClipApi.streams.current] = function () {
            controller.handleHistoryChanged(event.data
                ? event.data.history_revision : undefined);
        };
        handlers[ClipApi.streams.capture] = getSettings;
        handlers[ClipApi.streams.operation] = function () {
            const operation = event.data && event.data.operation;
            if (operation) {
                controller.applyOperation(operation);
                if (operation.status !== "started")
                    controller.scheduleRefresh();
            }
        };
        if (handlers[event.stream]) handlers[event.stream]();
    }
    onSendFailed: function (id, message) { controller.handleFailure(id, message); }
    onTransportFailed: function (message) { controller.handleTransportFailure(message); }
}
