import QtQuick
import "Model.js" as Model

Item {
    required property string providerId
    required property string displayName
    property string icon: ""
    property real priority: 0
    property bool providerEnabled: true
    property var prefixes: []
    property var capabilities: ({ query: true, actions: true, preview: false, subscriptions: false })
    property string status: "idle"
    property bool busy: false

    signal queryCompleted(var batch)
    signal queryFailed(var error)
    signal executionStarted(var request)
    signal executionFinished(var outcome)
    signal executionFailed(var outcome)

    function descriptor() {
        return Model.provider({
            id: providerId,
            name: displayName,
            icon: icon,
            priority: priority,
            enabled: providerEnabled,
            prefixes: prefixes,
            capabilities: capabilities
        });
    }

    function actionsFor(result) { return result && result.actions ? result.actions : []; }
    function primaryActionIdFor(result) { return result ? result.primaryActionId : ""; }

    function query(request) {
        queryFailed({
            providerId: providerId,
            queryId: request ? request.id : "",
            code: "query-not-implemented",
            message: displayName + " does not implement queries"
        });
    }

    function executePayload(request, action, rejectionMessage) {
        if (!request || !request.result || !request.result.payload)
            return false;
        executionStarted(request);
        if (action(request.actionId, request.result.payload) !== false)
            return true;
        executionFailed({ requestId: request.id, code: "action-rejected", message: rejectionMessage });
        return false;
    }
    function execute(request) {
        executionFailed({ providerId: providerId, requestId: request ? request.id : "",
            code: "execution-not-implemented", message: displayName + " does not implement actions" });
        return false;
    }

    function cancel(requestId) {}
}
