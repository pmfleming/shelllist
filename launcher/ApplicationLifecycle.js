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

function isActiveStatus(status) {
    return status === "accepted" || status === "running";
}

function isTerminalStatus(status) {
    return status === "completed" || status === "failed" || status === "cancelled";
}

if (typeof module !== "undefined") {
    module.exports = {
        expectedOperationAction: expectedOperationAction,
        operationMatches: operationMatches,
        isActiveStatus: isActiveStatus,
        isTerminalStatus: isTerminalStatus
    };
}
