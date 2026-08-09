import QtQuick
import Shelllist.Core as Core
import Shelllist.Io as Io
import "AppApi.js" as AppApi

Item {
    id: backend

    required property ApplicationController controller
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
        if (id === "session-subscribe" || id.indexOf("cancel-") === 0 || id.indexOf("shutdown-") === 0)
            return;
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            AppApi.protocol, AppApi.version, "app-daemon", "Application operation failed");
        if (error) {
            controller.handleFailure(id, error);
            return;
        }
        const data = envelope.data || ({});
        if (data.applications)
            controller.applyApplications(id, data.applications);
        if (data.operation)
            controller.applyOperation(id, data.operation);
    }
    function query(id, text, generation, limit, forceRefresh) {
        return call(id, forceRefresh ? AppApi.methods.refresh : AppApi.methods.query,
            { query: text, generation: generation, limit: limit });
    }
    function execute(id, params) { return call(id, AppApi.methods.execute, params); }
    function cancelRequest(requestId) { client.cancel("cancel-" + requestId, requestId); }

    Io.JsonlDaemonClient {
        id: client
        daemonName: "app-daemon"
        recoverProtocolErrors: true
        streams: [AppApi.streams.applications, AppApi.streams.windows, AppApi.streams.operation]
        active: backend.active
        onResponse: function (id, envelope, transportError) { backend.finish(id, envelope, transportError); }
        onEventReceived: function (event) {
            if (event.event === "subscribed")
                return;
            if (event.stream === AppApi.streams.applications || event.stream === AppApi.streams.windows)
                backend.controller.scheduleRefresh();
        }
        onTransportFailed: function (message) { backend.controller.handleTransportFailure(message); }
    }
}
