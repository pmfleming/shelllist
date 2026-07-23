import QtQuick
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
        const error = ClipApi.responseError(envelope, transportError);
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
        if (data.history)
            controller.applyHistory(id, data.history);
        else if (data.session)
            controller.applySession(data.session);
        else if (data.entry)
            controller.applyDetails(id, data.entry);
        else if (data.thumbnail)
            controller.applyThumbnail(id, data.thumbnail);
        else if (data.operation)
            controller.applyOperation(id, data.operation);
        else if (data.challenge)
            controller.applyWipeChallenge(data.challenge);
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
    function action(id, entry, actionName, sessionId) {
        return call(id, ClipApi.methods.entryAction, {
            entry_id: entry.id, revision: entry.revision, action: actionName, session_id: sessionId || null
        });
    }
    function prepareWipe() { return call("wipe-prepare", ClipApi.methods.wipePrepare, {}); }
    function commitWipe(challengeId) {
        return call("wipe-commit", ClipApi.methods.wipeCommit, { challenge_id: challengeId, response: "WIPE" });
    }
    function cancelRequest(requestId) { client.cancel("cancel-" + requestId, requestId); }

    ClipDaemonClient {
        id: client
        active: backend.active
        onResponse: function (id, envelope, transportError) { backend.finish(id, envelope, transportError); }
        onEventReceived: function (event) {
            if ((event.stream === ClipApi.streams.history || event.stream === ClipApi.streams.current)
                    && event.event !== "subscribed")
                backend.controller.scheduleRefresh();
        }
        onTransportFailed: function (message) { backend.controller.handleTransportFailure(message); }
    }
}
