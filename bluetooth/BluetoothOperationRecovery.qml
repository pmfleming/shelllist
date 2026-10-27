import QtQuick
import "BtApi.js" as BtApi

// Operation recovery is read-only and independent of prompts, scans and watch
// subscriptions. Missing evidence never releases a device's accepted-work guard.
Item {
    id: recovery
    required property BluetoothBackend backend
    required property BluetoothController controller
    property var operations: ({})
    property var finishedOperations: ({})
    property string statusRequestId: ""
    property string statusOperationId: ""
    property double statusStarted: 0
    property int pollIndex: 0

    function clearStatusRead(): void {
        statusRequestId = "";
        statusOperationId = "";
        statusStarted = 0;
    }
    function reset(): void {
        operations = ({});
        finishedOperations = ({});
        clearStatusRead();
        pollIndex = 0;
    }
    function apply(operation: var, adopt: bool, recovered: bool): bool {
        if (!BtApi.validOperation(operation))
            throw new Error("Missing or malformed native Bluetooth operation revision; matching daemon required");
        const id = operation.request_id;
        if (finishedOperations[id])
            return false;
        const previous = operations[id];
        if (!previous && !adopt)
            return false; // Pre-acceptance events are repaired by owned status, not replay.
        if (previous && (previous.device_key !== operation.device_key || previous.operation !== operation.operation
                || operation.revision <= previous.revision))
            return false;
        if (BtApi.activeOperation(operation)) {
            operations = BtApi.copyWith(operations, id, operation);
            if (previous)
                controller.handleOperationEvent(operation, recovered);
            else
                controller.handleOperationAccepted(operation);
        } else {
            operations = BtApi.copyWithout(operations, id);
            finishedOperations = BtApi.copyWith(finishedOperations, id, true);
            if (previous)
                controller.handleOperationEvent(operation, recovered);
        }
        return true;
    }
    function restore(snapshot: var): void {
        if (!BtApi.objectValue(snapshot) || !Array.isArray(snapshot.active) || !Array.isArray(snapshot.recent))
            throw new Error("Malformed Bluetooth operation snapshot");
        // Validate the entire collection before publishing any of it.
        if (!snapshot.active.concat(snapshot.recent).every(BtApi.validOperation)
                || !snapshot.active.every(BtApi.activeOperation)
                || snapshot.recent.some(BtApi.activeOperation))
            throw new Error("Malformed Bluetooth operation snapshot records");
        // Consumers share a transport owner, not local admission receipts.
        // Aggregate rows can reconcile known IDs, never adopt or retire peer work.
        for (const operation of snapshot.recent)
            apply(operation, false, true);
        for (const operation of snapshot.active)
            apply(operation, false, true);
        // Absence is neither completion nor cancellation. Keep accepted work
        // until status confirms an outcome, or explicitly mark it uncertain.
    }
    function unknown(id: string, message: string): void {
        const operation = operations[id];
        if (!operation || finishedOperations[id])
            return;
        const uncertain = Object.assign({}, operation, {outcome_unknown: true});
        operations = BtApi.copyWith(operations, id, uncertain);
        finishedOperations = BtApi.copyWith(finishedOperations, id, true);
        controller.handleOperationUnknown(uncertain, message + ". Outcome unknown; check the device before trying again.");
    }
    function poll(): void {
        if (statusRequestId) {
            if (Date.now() - statusStarted >= 5000)
                unknown(statusOperationId, "Bluetooth status read timed out");
            // Even after its local deadline, never overlap an outstanding read.
            return;
        }
        const ids = Object.keys(operations).filter(id => !operations[id].outcome_unknown);
        if (!backend.ready || !ids.length)
            return;
        const id = ids[pollIndex % ids.length];
        pollIndex = (pollIndex + 1) % ids.length;
        statusOperationId = id;
        statusRequestId = backend.nextRequestId("operation-status");
        statusStarted = Date.now();
        if (!backend.call(statusRequestId, BtApi.methods.operationStatus, {request_id: id})) {
            unknown(id, "Could not send Bluetooth status read");
            clearStatusRead();
        }
    }
    function finishStatus(id: string, operation: var, error: string): bool {
        if (!id || id !== statusRequestId)
            return false;
        const operationId = statusOperationId;
        clearStatusRead();
        if (finishedOperations[operationId])
            return true; // A newer terminal event (or uncertainty) already retired it.
        if (error || !BtApi.validOperation(operation) || operation.request_id !== operationId) {
            unknown(operationId, error || "Invalid Bluetooth status response");
            return true;
        }
        const previous = operations[operationId];
        if (previous && (operation.device_key !== previous.device_key || operation.operation !== previous.operation)) {
            unknown(operationId, "Mismatched Bluetooth status response");
            return true;
        }
        apply(operation, false, true);
        return true;
    }
    Timer {
        objectName: "bluetoothOperationPollTimer"
        interval: 1000
        repeat: true
        running: recovery.statusRequestId.length > 0
            || Object.values(recovery.operations).some(operation => !operation.outcome_unknown)
        onTriggered: recovery.poll()
    }
}
