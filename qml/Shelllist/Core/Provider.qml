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

    function descriptor(): var {
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

    function actionsFor(result: var): var { return result && result.actions ? result.actions : []; }
    function primaryActionIdFor(result: var): string { return result ? result.primaryActionId : ""; }

    function query(request: var): bool { return false; }

    function executePayload(request: var, action: var): bool {
        if (!request || !request.result || !request.result.payload)
            return false;
        return action(request.actionId, request.result.payload) !== false;
    }
    function execute(request: var): bool { return false; }

    function cancel(requestId: string): void {}
}
