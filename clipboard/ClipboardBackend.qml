import QtQuick
import "ClipApi.js" as ClipApi

Item {
    id: backend

    required property ClipboardController controller
    readonly property bool active: controller.uiActive
    property var pending: ({})

    function call(id, method, params) {
        const next = Object.assign({}, pending);
        next[id] = true;
        pending = next;
        client.call(id, method, params || ({}));
    }
    function finish(id, envelope, transportError) {
        const next = Object.assign({}, pending);
        delete next[id];
        pending = next;
        if (id === "session-subscribe" || id.indexOf("cancel-") === 0 || id.indexOf("shutdown-") === 0)
            return;
        const error = ClipApi.responseError(envelope, transportError);
        if (error) {
            controller.handleFailure(id, error);
            return;
        }
        const data = envelope.data || ({});
        if (data.history)
            controller.applyHistory(id, data.history);
        else if (data.session)
            controller.applySession(data.session);
    }
    function query(id, text, generation, limit) {
        call(id, ClipApi.methods.historyQuery, { query: text, generation: generation, limit: limit });
    }
    function beginSession() { call("session-begin", ClipApi.methods.sessionBegin, {}); }
    function cancelRequest(requestId) { client.cancel("cancel-" + requestId, requestId); }

    ClipDaemonClient {
        id: client
        active: backend.active
        onResponse: function (id, envelope, transportError) { backend.finish(id, envelope, transportError); }
        onEventReceived: function (event) {
            if (event.stream === ClipApi.streams.history && event.event !== "subscribed")
                backend.controller.refresh();
        }
        onTransportFailed: function (message) { backend.controller.handleTransportFailure(message); }
    }
}
