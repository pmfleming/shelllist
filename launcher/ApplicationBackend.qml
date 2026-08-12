import Shelllist.Core as Core
import Shelllist.Io as Io
import "AppApi.js" as AppApi

Io.DaemonBackend {
    required property ApplicationController controller
    daemonName: "app-daemon"
    streams: [AppApi.streams.applications, AppApi.streams.windows, AppApi.streams.operation]
    active: controller.uiActive

    function finish(id: string, envelope: var, transportError: string): void {
        const error = Core.ApiEnvelope.responseError(envelope, transportError,
            AppApi.protocol, AppApi.version, daemonName, "Application operation failed");
        if (error) {
            controller.handleFailure(id, error);
            return;
        }
        const data = envelope.data || ({});
        if (data.applications)
            controller.applyApplications(id, data.applications);
        if (data.history)
            controller.applyResourceHistory(id, data.history);
        if (data.operation)
            controller.applyOperation(id, data.operation);
    }

    function query(id: string, text: string, generation: int, limit: int, forceRefresh: bool): bool {
        return call(id, forceRefresh ? AppApi.methods.refresh : AppApi.methods.query,
            { query: text, generation: generation, limit: limit });
    }

    function history(id: string, targetId: string, limit: int): bool {
        return call(id, AppApi.methods.history,
            { target_id: targetId, since_ms: null, limit: limit });
    }

    function execute(id: string, params: var): bool {
        return call(id, AppApi.methods.execute, params);
    }

    function cancelRequest(requestId: string): bool {
        return cancel(requestId, "cancel-" + requestId);
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventReceived: function (event) {
        if (event.event !== "subscribed"
                && (event.stream === AppApi.streams.applications || event.stream === AppApi.streams.windows))
            controller.scheduleRefresh();
    }
    onSendFailed: function (id, message) { controller.handleFailure(id, message); }
    onTransportFailed: function (message) { controller.handleTransportFailure(message); }
}
