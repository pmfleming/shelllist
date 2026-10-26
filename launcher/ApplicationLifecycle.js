.pragma library

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
    return targetId === currentTargetId && range === currentRange && (inFlight || forceRefresh !== true);
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
    return isFinite(value) && value >= 0 && Math.floor(value) === value && value <= 9007199254740991 ? value : null;
}

function operationMatches(activeRequest, activeTargetId, operation) {
    if (!activeRequest || !operation)
        return false;
    return typeof activeRequest.operationAction === "string" && activeRequest.operationAction.length > 0
        && operation.target_id === activeTargetId && operation.action === activeRequest.operationAction;
}

function acceptedOperationMatches(activeRequest, responseId) {
    return !!activeRequest && !!responseId && responseId === activeRequest.id;
}

function currentOperationMatches(activeRequest, activeTargetId, activeOperationId, operation) {
    if (!activeRequest)
        return false;
    return operationMatches(activeRequest, activeTargetId, operation) && (!activeOperationId || operation.id === activeOperationId);
}

function operationTransition(activeRequest, activeTargetId, activeOperationId, responseId, operation) {
    if (!operation || !operation.id)
        return null;
    if (!operationMatches(activeRequest, activeTargetId, operation) || (activeOperationId && operation.id !== activeOperationId))
        return null;
    const status = operation.status;
    if (!["accepted", "running", "completed", "failed", "cancelled"].includes(status))
        return null;
    if (status === "accepted") {
        if (!acceptedOperationMatches(activeRequest, responseId))
            return null;
        return {
            stage: "active",
            accepted: true,
            status: status,
            operationId: operation.id
        };
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
