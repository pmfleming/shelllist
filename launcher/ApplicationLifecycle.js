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
    return Number.isSafeInteger(value) && value >= 0 ? value : null;
}

// Every observation uses the captured native identity. Admission additionally
// needs its request ID; unknown outcomes need an admitted or recoverable ID.
// Revision validation/publication belongs to the operation owner.
function operationStage(record, responseId, operation) {
    const request = record.request;
    if (!operation || !operation.id || typeof request.operationAction !== "string" || !request.operationAction
            || operation.target_id !== request.result.id || operation.action !== request.operationAction
            || (record.operationId && operation.id !== record.operationId))
        return "";
    if (operation.status === "unknown")
        return operation.id === (record.operationId || record.recoveryId) ? "unknown" : "";
    if (operation.status === "accepted" && (!responseId || responseId !== request.id))
        return "";
    if (["accepted", "running"].includes(operation.status))
        return "active";
    return ["completed", "failed", "cancelled"].includes(operation.status) ? "terminal" : "";
}
