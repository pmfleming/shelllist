import QtQuick

// Delivery/ownership fences only. Never reconstruct or replay a clipboard effect.
Item {
    id: recovery
    required property DaemonBackend backend
    property var requests: ({})
    property var operations: ({})
    property string historyEpoch: ""
    property double historyRevision: 0
    property int historyBarrier: 0
    property string statusPending: ""
    property double statusPendingSince: 0
    property int statusTimeoutMs: 5000
    property int pollIndex: 0
    property string error: ""
    signal historyInvalidated
    signal readDiscarded(string id)
    signal operationUncertain(string id, string message)

    function stampValid(stamp): bool {
        return !!stamp && typeof stamp.epoch === "string" && stamp.epoch.length > 0
            && Number.isSafeInteger(stamp.revision) && stamp.revision >= 1;
    }
    function running(operation): bool {
        return operation && ["started", "progress"].includes(operation.status);
    }
    function sending(id: string, method: string, params: var): var {
        const action = method === "clipboard.entry.action" ? params.action
            : (["clipboard.capture.interactive", "clipboard.capture.screenshot"].includes(method) ? "screenshot" : "");
        requests = Object.assign({}, requests, {[id]: {method: method, barrier: historyBarrier, operationId: params.operation_id || "", action: action}});
        return params;
    }
    function forget(id: string): void {
        const next = Object.assign({}, requests);
        delete next[id];
        requests = next;
        if (statusPending === id) statusPending = "";
    }
    function sendFailed(id: string): void {
        const request = requests[id];
        forget(id);
        if (request?.method === "clipboard.operation.status")
            uncertain(request.operationId, "Clipboard operation outcome is unknown; do not replay");
    }
    function uncertain(id: string, message: string): void {
        const record = operations[id];
        if (!record || !record.running) return;
        operations = Object.assign({}, operations, {[id]: Object.assign({}, record, {running: false})});
        operationUncertain(id, message);
    }
    function rejected(envelope: var, message: string): var {
        error = message;
        return Object.assign({}, envelope, {ok: false, data: {}, error: {code: "recovery-metadata", message: message}});
    }
    function historyRead(id: string, request: var, envelope: var): var {
        const stamp = envelope.data?._history;
        if (!stampValid(stamp))
            return rejected(envelope, "Missing clipboard history watermark; matching daemon required");
        if (request.barrier !== historyBarrier || (historyEpoch && (historyEpoch !== stamp.epoch || stamp.revision < historyRevision))) {
            readDiscarded(id);
            return undefined;
        }
        if (request.method === "clipboard.history.query" && (!Array.isArray(envelope.data?.history?.entries)
                || typeof envelope.data.history.snapshot_revision !== "string"
                || envelope.data.history.entries.some(entry => !entry || typeof entry.id !== "string" || !entry.id
                    || !Number.isSafeInteger(entry.revision) || entry.revision < 1)))
            return rejected(envelope, "Malformed clipboard history snapshot");
        if (request.method === "clipboard.history.revision" && typeof envelope.data.revision !== "string")
            return rejected(envelope, "Malformed clipboard history token");
        historyEpoch = stamp.epoch;
        historyRevision = stamp.revision;
        return envelope;
    }
    function acceptOperation(operation: var, initial: bool): bool {
        if (!operation || typeof operation.id !== "string" || !operation.id
                || typeof operation.action !== "string" || typeof operation.status !== "string"
                || !["started", "progress", "completed", "failed", "cancelled", "unknown", "paste-prepared"].includes(operation.status)
                || !stampValid(operation._publication)) {
            error = "Missing or malformed clipboard operation watermark; matching daemon required";
            return false;
        }
        const stamp = operation._publication;
        const previous = operations[operation.id];
        if (!initial && !previous) return false; // Another consumer sharing this owner.
        if (previous && previous.action !== operation.action) {
            error = "Clipboard operation action mismatch; outcome unknown";
            return false;
        }
        if (previous && (!previous.running || previous.epoch !== stamp.epoch || stamp.revision <= previous.revision)) return false;
        const next = Object.assign({}, operations, {[operation.id]: {
            epoch: stamp.epoch, revision: stamp.revision, running: running(operation), action: operation.action
        }});
        const ids = Object.keys(next);
        for (const id of ids) {
            if (Object.keys(next).length <= 64) break;
            if (!next[id].running && id !== operation.id) delete next[id];
        }
        operations = next;
        if (operation.status === "unknown") {
            operationUncertain(operation.id, "Clipboard operation outcome is unknown; do not replay");
            return false;
        }
        return true;
    }
    function received(id: string, envelope: var, transportError: string): var {
        error = "";
        const request = requests[id];
        forget(id);
        if (!request) return envelope;
        const statusRead = request.method === "clipboard.operation.status";
        if (transportError || !envelope?.ok) {
            if (statusRead) {
                uncertain(request.operationId, "Clipboard operation outcome is unknown; do not replay");
                return undefined;
            }
            return envelope;
        }
        if (["clipboard.history.query", "clipboard.history.revision"].includes(request.method))
            return historyRead(id, request, envelope);
        if (["clipboard.entry.details", "clipboard.entry.thumbnail"].includes(request.method) && request.barrier !== historyBarrier) {
            readDiscarded(id);
            return undefined;
        }
        if (envelope.data?.operation) {
            const operation = envelope.data.operation;
            if (request.action && operation.action !== request.action)
                return rejected(envelope, "Clipboard operation action mismatch; outcome unknown");
            if (statusRead && operation.id !== request.operationId) {
                uncertain(request.operationId, "Clipboard status identity mismatch; outcome unknown");
                return undefined;
            }
            if (!acceptOperation(operation, !statusRead)) {
                if (error) {
                    if (statusRead) uncertain(request.operationId, error);
                    else return rejected(envelope, error);
                }
                return undefined;
            }
        } else if (statusRead) {
            uncertain(request.operationId, "Clipboard operation outcome is unknown; do not replay");
            return undefined;
        }
        return envelope;
    }
    function invalidateHistory(): void {
        historyBarrier++;
        historyInvalidated();
    }
    function observe(event: var): var {
        error = "";
        if (["clipboard.history.changed", "clipboard.current.changed"].includes(event.stream)) {
            if (event.event === "subscribed") return false;
            const stamp = event.data?._history;
            if (!stampValid(stamp)) {
                invalidateHistory();
                return false;
            }
            if (historyEpoch && (historyEpoch !== stamp.epoch || stamp.revision <= historyRevision)) return false;
            historyEpoch = stamp.epoch;
            historyRevision = stamp.revision;
            invalidateHistory();
            return false; // One invalidation per watermark, even across both streams.
        }
        if (event.stream === "clipboard.operation") {
            if (event.event === "subscribed") return false;
            if (event.event === "gap") { poll(); return false; }
            const operation = event.data?.operation;
            if (!acceptOperation(operation, false)) {
                if (error && operation?.id) uncertain(operation.id, error);
                return false;
            }
        }
        return event;
    }
    function invalidEvent(event: var, message: string): void {
        error = message;
        if (["clipboard.history.changed", "clipboard.current.changed"].includes(event?.stream)) invalidateHistory();
        if (event?.stream === "clipboard.operation") poll();
    }
    function poll(): void {
        if (!backend.active || !backend.ready) return;
        if (statusPending) {
            if (Date.now() - statusPendingSince >= statusTimeoutMs)
                uncertain(requests[statusPending]?.operationId, "Clipboard status deadline exceeded; outcome unknown; do not replay");
            return; // Keep the one read outstanding; a timeout never starts another.
        }
        const ids = Object.keys(operations).filter(id => operations[id].running);
        if (!ids.length) return;
        const operationId = ids[pollIndex++ % ids.length];
        const id = backend.nextRequestId("clip-status");
        statusPending = id;
        statusPendingSince = Date.now();
        if (!backend.call(id, "clipboard.operation.status", {operation_id: operationId})) statusPending = "";
    }
    function reset(message: string): void {
        requests = ({});
        operations = ({});
        statusPending = "";
        historyEpoch = "";
        historyRevision = 0;
        historyBarrier++;
        error = message;
    }
    Connections {
        target: recovery.backend
        function onReadyChanged(): void {
            if (recovery.backend.ready) return;
            // Graceful idle shutdown is not a transport failure. Still permit a
            // new producer epoch on reopening, while draining accepted receipts.
            recovery.historyEpoch = "";
            recovery.historyRevision = 0;
            recovery.historyBarrier++;
        }
    }
    Timer { interval: 1000; repeat: true; running: recovery.backend.active && recovery.backend.ready; onTriggered: recovery.poll() }
}
