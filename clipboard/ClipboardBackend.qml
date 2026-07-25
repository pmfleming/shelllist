import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import "ClipApi.js" as ClipApi

Item {
    id: backend

    required property ClipboardController controller
    readonly property bool active: controller.uiActive
    property var pending: ({})

    function call(id, method, params) {
        if (pending[id])
            return false;
        const next = Object.assign({}, pending);
        next[id] = true;
        pending = next;
        client.call(id, method, params || ({}));
        return true;
    }
    function finish(id, envelope, transportError) {
        const next = Object.assign({}, pending);
        delete next[id];
        pending = next;
        if (isTransportControl(id))
            return;
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            "clip-api", 1, "clip-daemon", "Clipboard operation failed");
        if (error) {
            controller.handleFailure(id, error);
            return;
        }
        applyResponse(id, envelope.data || ({}));
    }
    function isTransportControl(id) {
        return id === "session-subscribe" || id.indexOf("cancel-") === 0 || id.indexOf("shutdown-") === 0;
    }
    function applyResponse(id, data) {
        const handlers = ({
            history: function (value) { controller.applyHistory(id, value); },
            session: controller.applySession,
            entry: function (value) {
                if (id === "edit-commit") controller.detailState.applyEditCommit(value);
                else controller.detailState.applyDetails(id, value);
            },
            thumbnail: function (value) { controller.detailState.applyThumbnail(id, value); },
            operation: function (value) { controller.applyOperation(value); },
            challenge: controller.applyWipeChallenge,
            edit: function (value) { controller.detailState.applyEdit(id, value); },
            settings: controller.applySettings,
            capture: controller.applyCapture
        });
        Object.keys(data).forEach(function (key) {
            if (handlers[key]) handlers[key](data[key]);
        });
    }
    function query(id, text, generation, limit) {
        return call(id, ClipApi.methods.historyQuery, { query: text, generation: generation, limit: limit });
    }
    function details(id, entry) {
        return call(id, ClipApi.methods.entryDetails, { entry_id: entry.id, revision: entry.revision });
    }
    function thumbnail(id, entry) {
        return call(id, ClipApi.methods.entryThumbnail, { entry_id: entry.id, revision: entry.revision, edge: 640 });
    }
    function beginSession() { return call("session-begin", ClipApi.methods.sessionBegin, {}); }
    function hideSession(sessionId) { return call("session-hidden", ClipApi.methods.sessionHidden, { session_id: sessionId }); }
    function endSession(sessionId) { return call("session-end", ClipApi.methods.sessionEnd, { session_id: sessionId }); }
    function action(id, entry, actionName, sessionId, fileIndex) {
        return call(id, ClipApi.methods.entryAction, {
            entry_id: entry.id, revision: entry.revision, action: actionName,
            session_id: sessionId || null, file_index: fileIndex === undefined ? null : fileIndex
        });
    }
    function beginEdit(entry) {
        return call("edit-begin", ClipApi.methods.editBegin, { entry_id: entry.id, revision: entry.revision });
    }
    function commitEdit(editId, value) {
        return call("edit-commit", ClipApi.methods.editCommit, { edit_id: editId, value: value });
    }
    function cancelEdit(editId) {
        return call("edit-cancel", ClipApi.methods.editCancel, { edit_id: editId });
    }
    function getSettings() { return call("settings-get", ClipApi.methods.settingsGet, {}); }
    function updateSettings(values) { return call("settings-update", ClipApi.methods.settingsUpdate, values); }
    function setPaused(paused, privateMode) {
        return call("capture-pause", ClipApi.methods.captureSetPaused, { paused: paused, private_mode: privateMode });
    }
    function captureScreenshot(x, y, width, height) {
        return call("capture-screenshot", ClipApi.methods.captureScreenshot, {
            x: x, y: y, width: width, height: height
        });
    }
    function prepareWipe() { return call("wipe-prepare", ClipApi.methods.wipePrepare, {}); }
    function commitWipe(challengeId) {
        return call("wipe-commit", ClipApi.methods.wipeCommit, { challenge_id: challengeId, response: "WIPE" });
    }
    function cancelRequest(requestId) { client.cancel("cancel-" + requestId, requestId); }
    function cancelOperation(operationId) { client.cancel("cancel-operation-" + operationId, operationId); }

    Io.JsonlDaemonClient {
        id: client
        daemonName: "clip-daemon"
        recoverProtocolErrors: true
        streams: [ClipApi.streams.history, ClipApi.streams.current, ClipApi.streams.operation,
            ClipApi.streams.capture, ClipApi.streams.session]
        active: backend.active
        onResponse: function (id, envelope, transportError) { backend.finish(id, envelope, transportError); }
        onEventReceived: function (event) {
            if (event.event === "subscribed") return;
            const handlers = ({});
            handlers[ClipApi.streams.history] = backend.controller.scheduleRefresh;
            handlers[ClipApi.streams.current] = backend.controller.scheduleRefresh;
            handlers[ClipApi.streams.capture] = backend.getSettings;
            if (handlers[event.stream]) handlers[event.stream]();
        }
        onTransportFailed: function (message) { backend.controller.handleTransportFailure(message); }
    }
}
