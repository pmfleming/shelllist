.pragma library

function expectedOperationAction(actionId) {
    const value = String(actionId || "");
    if (value.indexOf("focus-window-") === 0)
        return "focus-window";
    if (value.indexOf("close-window-") === 0)
        return "close-window";
    if (value.indexOf("desktop-action-") === 0)
        return "desktop-action";
    return value;
}

function operationMatches(activeRequest, activeTargetId, operation) {
    if (!activeRequest || !operation)
        return false;
    return operation.target_id === activeTargetId
        && operation.action === expectedOperationAction(activeRequest.actionId);
}

function acceptedOperationMatches(activeRequest, responseId) {
    return !!activeRequest && (!responseId || responseId === activeRequest.id);
}

function currentOperationMatches(activeRequest, activeTargetId, activeOperationId, operation) {
    if (!activeRequest)
        return false;
    return activeOperationId
        ? operation.id === activeOperationId
        : operationMatches(activeRequest, activeTargetId, operation);
}

function operationTransition(activeRequest, activeTargetId, activeOperationId, responseId, operation) {
    if (!operation || !operation.id)
        return null;
    const status = operation.status || "completed";
    if (status === "accepted") {
        if (!acceptedOperationMatches(activeRequest, responseId))
            return null;
        return { stage: "active", accepted: true, status: status, operationId: operation.id };
    }
    if (!currentOperationMatches(activeRequest, activeTargetId, activeOperationId, operation))
        return null;
    return {
        stage: status === "running" ? "active" : "terminal",
        accepted: false,
        status: status,
        operationId: operation.id
    };
}
