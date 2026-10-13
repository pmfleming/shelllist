import QtQuick
import "BatteryApi.js" as BatteryApi

// Operation acknowledgement is not completion. Only status is retried; never
// replay a start when its ID or its bus owner has been lost.
Item {
    id: operations
    required property var backend
    property var requests: ({})
    property var statusRequests: ({})

    function start(prefix: string, method: string, params: var): bool {
        const id = backend.nextRequestId(prefix);
        const next = Object.assign({}, requests);
        next[id] = { operationId: "", started: Date.now() };
        requests = next;
        // Retain a separate operation-lifetime state fence. The start reply
        // retires its ordinary request context before the terminal result exists.
        if (backend.requestPolicy)
            backend.requestPolicy.sending(completionKey(id), BatteryApi.methods.operationStart, {});
        if (backend.call(id, BatteryApi.methods.operationStart, { method: method, params: params }))
            return true;
        forget(id);
        return false;
    }

    function completionKey(id: string): string {
        return "battery-operation-result::" + id;
    }

    function forget(id: string): void {
        if (backend.requestPolicy)
            backend.requestPolicy.sendFailed(completionKey(id));
        const next = Object.assign({}, requests);
        delete next[id];
        requests = next;
    }

    function reset(): void {
        requests = ({});
        statusRequests = ({});
    }

    function poll(): void {
        Object.keys(requests).forEach(function (id) {
            const operation = requests[id];
            if (!operation.operationId || Object.values(statusRequests).includes(id))
                return;
            if (Date.now() - operation.started > 360000) {
                forget(id);
                backend.rejectRequest(id, "Battery operation outcome unknown; inspect current state before another action");
                backend.snapshot();
                return;
            }
            const statusId = backend.nextRequestId("battery-operation-status");
            const next = Object.assign({}, statusRequests);
            next[statusId] = id;
            statusRequests = next;
            if (!backend.call(statusId, BatteryApi.methods.operationStatus, { operation_id: operation.operationId })) {
                delete next[statusId];
                statusRequests = Object.assign({}, next);
            }
        });
    }

    function cancel(): void {
        Object.keys(requests).forEach(function (id) {
            const operation = requests[id];
            if (operation.operationId)
                backend.callSequenced("battery-operation-cancel", BatteryApi.methods.operationCancel, { operation_id: operation.operationId });
        });
    }

    function accept(id: string, envelope: var, transportError: string): bool {
        if (backend.requestKind(id) === "battery-operation-cancel")
            return true; // Intent only. Continue status lookup even after rejection.
        const original = statusRequests[id] || id;
        if (statusRequests[id]) {
            const next = Object.assign({}, statusRequests);
            delete next[id];
            statusRequests = next;
        }
        if (!requests[original])
            return backend.requestKind(id) === "battery-operation-status";
        const error = backend.responseError(envelope, transportError, "Battery operation outcome unknown");
        const operation = envelope && envelope.data ? envelope.data.operation : null;
        const expected = requests[original].operationId;
        if (error.length > 0 || !operation || !operation.id || (expected && expected !== operation.id) || !["running", "finished"].includes(operation.state)) {
            forget(original);
            backend.rejectRequest(original, error || "Invalid battery operation acknowledgement; outcome unknown");
            backend.snapshot();
            return true;
        }
        if (operation.state === "finished") {
            const response = backend.requestPolicy ? backend.requestPolicy.received(completionKey(original), operation.response, "") : operation.response;
            forget(original);
            backend.finish(original, response, "");
            backend.snapshot();
        } else {
            const next = Object.assign({}, requests);
            next[original] = Object.assign({}, next[original], { operationId: operation.id });
            requests = next;
        }
        return true;
    }

    Timer {
        interval: 1000
        repeat: true
        running: Object.keys(operations.requests).length > 0 && operations.backend.ready
        onTriggered: operations.poll()
    }
}
