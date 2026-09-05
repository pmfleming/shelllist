.pragma library

function completionDisposition(status, closingAction) {
    const completed = status === "completed";
    return {
        completed: completed,
        removeInstances: completed && closingAction,
        closeSurface: completed && !closingAction
    };
}

function requestKind(id) {
    if (id.indexOf("history-") === 0)
        return "history";
    if (id.indexOf("settings-") === 0)
        return "settings";
    if (id.indexOf("action-") === 0)
        return "action";
    return "other";
}

function historyRequestCovered(targetId, currentTargetId, inFlight, forceRefresh, range, currentRange) {
    return targetId === currentTargetId && range === currentRange
        && (inFlight || forceRefresh !== true);
}

function mergeResourceHistory(existing, incoming, sinceMs, untilMs) {
    const inRange = function (point) {
        const timestamp = Number(point.timestamp_ms);
        return isFinite(timestamp) && timestamp >= sinceMs && timestamp <= untilMs;
    };
    if (incoming.length === 0) {
        const retained = existing.filter(inRange);
        return retained.length === existing.length ? existing : retained;
    }
    const byTimestamp = new Map();
    existing.concat(incoming).forEach(function (point) {
        if (inRange(point))
            byTimestamp.set(Number(point.timestamp_ms), point);
    });
    return Array.from(byTimestamp.values()).sort(function (left, right) {
        return Number(left.timestamp_ms) - Number(right.timestamp_ms);
    });
}

function expectedRevision(value) {
    if (typeof value !== "number")
        return null;
    return isFinite(value) && value >= 0 && Math.floor(value) === value
        && value <= 9007199254740991 ? value : null;
}

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
