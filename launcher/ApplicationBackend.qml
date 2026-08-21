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
        if (data.settings)
            controller.applyApplicationSettings(id, data.settings);
        if (data.operation)
            controller.applyOperation(id, data.operation);
    }

    function query(id: string, text: string, category: string,
            generation: int, limit: int, forceRefresh: bool): bool {
        return call(id, forceRefresh ? AppApi.methods.refresh : AppApi.methods.query,
            { query: text, category: category, generation: generation, limit: limit });
    }

    function history(id: string, targetId: string, sinceMs: double,
            cursor: var, limit: int): bool {
        return call(id, AppApi.methods.history, {
            target_id: targetId,
            since_ms: sinceMs,
            cursor: cursor,
            limit: limit
        });
    }

    function execute(id: string, params: var): bool {
        return call(id, AppApi.methods.execute, params);
    }

    function updateSettings(id: string, targetId: string, category: string): bool {
        return call(id, AppApi.methods.settingsUpdate, {
            target_id: targetId,
            category: category
        });
    }

    function cancelRequest(requestId: string): bool {
        return cancel(requestId, "cancel-" + requestId);
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventReceived: function (event) {
        if (event.event === "subscribed")
            return;
        if (event.stream === AppApi.streams.operation) {
            const operation = event.data && event.data.operation;
            if (operation)
                controller.applyOperation("", operation);
            return;
        }
        if (event.stream === AppApi.streams.applications
                || event.stream === AppApi.streams.windows)
            controller.scheduleRefresh();
    }
    onSendFailed: function (id, message) { controller.handleFailure(id, message); }
    onTransportFailed: function (message) { controller.handleTransportFailure(message); }
}
