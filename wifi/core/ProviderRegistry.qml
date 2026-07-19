pragma ComponentBehavior: Bound

import QtQuick
import "Model.js" as Model

Item {
    id: registry

    default property list<Provider> providers
    property int executionSequence: 0

    signal queryBatchReceived(var batch)
    signal queryFailed(var error)
    signal actionDispatched(var request)
    signal actionRejected(var rejection)

    function providerById(providerId) {
        for (let index = 0; index < providers.length; index++)
            if (providers[index].providerId === providerId)
                return providers[index];
        return null;
    }

    function descriptors() {
        return Array.prototype.map.call(providers, function (item) { return item.descriptor(); });
    }

    function validate() {
        const seen = ({});
        descriptors().forEach(function (descriptor) {
            if (seen[descriptor.id])
                throw new Error("providers: duplicate provider id " + JSON.stringify(descriptor.id));
            seen[descriptor.id] = true;
        });
        return true;
    }

    function query(request) {
        const normalized = Model.queryRequest(request);
        const selected = normalized.providerIds;
        let dispatched = 0;
        for (let index = 0; index < providers.length; index++) {
            const itemProvider = providers[index];
            const descriptor = itemProvider.descriptor();
            if (!descriptor.enabled || !descriptor.capabilities.query)
                continue;
            if (selected.length > 0 && selected.indexOf(descriptor.id) < 0)
                continue;
            itemProvider.query(normalized);
            dispatched += 1;
        }
        return dispatched;
    }

    function cancelQuery(requestId) {
        for (let index = 0; index < providers.length; index++)
            if (providers[index].providerEnabled)
                providers[index].cancel(requestId);
    }

    function actionsFor(result) {
        if (!result)
            return [];
        const itemProvider = providerById(result.providerId);
        if (!itemProvider || !itemProvider.providerEnabled)
            return [];
        return (itemProvider.actionsFor(result) || []).map(Model.action);
    }

    function defaultActionFor(result) {
        if (!result)
            return null;
        const itemProvider = providerById(result.providerId);
        if (!itemProvider || !itemProvider.providerEnabled)
            return null;
        const actions = actionsFor(result);
        const requested = itemProvider.primaryActionIdFor(result);
        return Model.actionById(actions, requested)
            || actions.find(function (item) { return item.role === "default" && item.visible; })
            || null;
    }

    function execute(result, actionId, context) {
        if (!result)
            return reject("missing-result", "No result is selected", "", actionId);
        const itemProvider = providerById(result.providerId);
        if (!itemProvider || !itemProvider.providerEnabled)
            return reject("provider-unavailable", "Provider " + result.providerId + " is unavailable", result.key, actionId);
        const actions = actionsFor(result);
        const selectedAction = actionId ? Model.actionById(actions, actionId) : defaultActionFor(result);
        if (!selectedAction)
            return reject("action-unavailable", "No action is available", result.key, actionId);
        if (!selectedAction.visible || !selectedAction.enabled)
            return reject("action-disabled", "Action " + selectedAction.id + " is unavailable", result.key, selectedAction.id);
        executionSequence += 1;
        const request = Model.executionRequest({
            id: "action-" + Date.now() + "-" + executionSequence,
            result: result,
            action: selectedAction,
            context: context || ({})
        });
        if (itemProvider.execute(request) === false)
            return reject("provider-rejected", "Provider " + result.providerId + " rejected action " + selectedAction.id, result.key, selectedAction.id);
        actionDispatched(request);
        return true;
    }

    function reject(code, message, resultKey, actionId) {
        actionRejected({ code: code, message: message, resultKey: resultKey || "", actionId: actionId || "" });
        return false;
    }

    Instantiator {
        model: registry.providers

        delegate: Connections {
            required property var modelData

            target: modelData
            function onQueryCompleted(batch) { registry.queryBatchReceived(batch); }
            function onQueryFailed(error) { registry.queryFailed(error); }
        }
    }
}
