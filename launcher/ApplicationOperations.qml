import QtQuick
import "ApplicationLifecycle.js" as Lifecycle
import "ApplicationPresentation.js" as Presentation

// Resident request ownership is independent of the selected result and panel
// visibility. Only the owning operation may retire its pending target.
Item {
    id: operations
    required property ApplicationController controller
    required property ApplicationBackend backend
    property var pending: ({})
    property var feedback: Object.create(null)
    readonly property int count: Object.keys(pending).length

    function forTarget(targetId: string): var {
        return Object.values(pending).find(record => record.request.result.id === targetId) || null;
    }
    function busy(targetId: string): bool { return forTarget(targetId) !== null; }
    function message(targetId: string, windowId: string): string {
        const record = forTarget(targetId) || feedback[targetId];
        if (!record || (windowId && !record.windowIds.includes(windowId)))
            return "";
        return record.message;
    }
    function focusSucceeded(targetId: string, windowId: string): bool {
        const record = forTarget(targetId) || feedback[targetId];
        return !!record && record.status === "completed"
            && Lifecycle.expectedOperationAction(record.request.actionId) === "focus-window"
            && record.windowIds.includes(windowId);
    }
    function publish(record: var): void {
        const targetId = record.request.result.id;
        const entries = Object.entries(feedback).filter(entry => entry[0] !== targetId);
        const next = Object.create(null);
        entries.concat([[targetId, record]]).slice(-64).forEach(entry => next[entry[0]] = entry[1]);
        feedback = next;
    }
    function store(record: var): void {
        pending = Object.assign({}, pending, {[record.request.id]: record});
        publish(record);
    }
    function progressMessage(request: var, params: var): string {
        const title = request.result.title;
        switch (params.action) {
        case "activate":
            return (request.result.payload.instances || []).length > 0
                ? qsTr("Focusing %1…").arg(title) : qsTr("Launching %1…").arg(title);
        case "launch":
            return qsTr("Launching %1…").arg(title);
        case "focus-window":
            return qsTr("Focusing %1…").arg(request.action.label);
        case "close-window":
            return qsTr("Closing window of %1…").arg(title);
        case "close":
            return qsTr("Closing windows of %1…").arg(title);
        default:
            return request.action.label + "…";
        }
    }
    function start(request: var, params: var): bool {
        if (busy(request.result.id) || count >= 32)
            return false;
        const windows = request.result.payload.instances || [];
        const windowId = (request.action.metadata || {}).windowId;
        const record = {
            request: {id: request.id, actionId: request.actionId,
                result: {id: request.result.id, title: request.result.title},
                action: {label: request.action.label}},
            operationId: "", statusRequestId: "", status: "", checks: 0,
            generation: controller.uiGeneration, viewEpoch: controller.actionViewEpoch, handedOff: false,
            windowIds: windowId ? [windowId] : windows.map(window => window.id),
            progressMessage: progressMessage(request, params),
            message: progressMessage(request, params)
        };
        store(record);
        if (!backend.execute(request.id, params)) {
            fail(request.id, "Could not send application action");
            return false;
        }
        return true;
    }
    function handOff(record: var): void {
        if (record.handedOff)
            return;
        record.handedOff = true;
        // A delayed result must not dismiss a reopened panel or another result.
        if (controller.uiActive && controller.uiGeneration === record.generation
                && controller.actionViewEpoch === record.viewEpoch && controller.selectedResult && controller.selectedResult.id === record.request.result.id)
            controller.closeWindowRequested();
    }
    function apply(responseId: string, operation: var): void {
        const original = pending[responseId] || Object.values(pending).find(record => record.operationId && record.operationId === operation?.id);
        if (!original)
            return; // An event before admission is recovered with an owned status read.
        const transition = Lifecycle.operationTransition(original.request, original.request.result.id, original.operationId, responseId, operation);
        if (!transition)
            return;
        const record = Object.assign({}, original, {operationId: operation.id, status: transition.status,
            placement: operation.placement || null, close: operation.close || null,
            windowIds: Array.isArray(operation.close?.targeted_window_ids) ? operation.close.targeted_window_ids : original.windowIds,
            checks: original.operationId ? original.checks : 0});
        const closing = Presentation.isCloseAction(record.request.actionId);
        if (transition.stage === "active")
            updateActive(record, operation, closing);
        else
            complete(record, operation, closing);
    }
    function updateActive(record: var, operation: var, closing: bool): void {
        record.message = record.checks >= 3
            ? record.request.action.label + ": still waiting for confirmation" : record.progressMessage;
        // Publish ownership before checked process/D-Bus handoff dismisses the
        // chooser; window placement may still take seconds.
        store(record);
        if (!closing && operation.launch_backend && operation.launch_scope) {
            handOff(record);
            store(record);
        }
    }
    function complete(record: var, operation: var, closing: bool): void {
        const completed = record.status === "completed";
        const warning = !completed || (closing
            ? record.close?.status !== "closed"
            : ["activate", "launch", "desktop-action"].includes(Lifecycle.expectedOperationAction(record.request.actionId))
                && ["unavailable", "failed"].includes(record.placement?.status));
        record.message = completed && closing && !record.close
            ? "Close outcome unconfirmed; check windows before trying again"
            : (operation.message || "Application action " + record.status);
        // Placement is daemon-owned. A launched app must not be replayed because
        // its move could not be confirmed; retain/show the partial-success warning
        // even when checked handoff already dismissed the chooser.
        if (!warning && !closing)
            handOff(record);
        retire(record);
        if (warning)
            reportFailure(record);
        if (closing && controller.uiActive)
            controller.refresh(false);
    }
    function retire(record: var): void {
        const next = Object.assign({}, pending);
        delete next[record.request.id];
        pending = next;
        publish(record);
    }
    function reportFailure(record: var): void {
        if (!controller.uiActive || controller.uiGeneration !== record.generation
                || !controller.selectedResult || controller.selectedResult.id !== record.request.result.id)
            controller.backgroundActionFailed(record.request.result.title, record.message);
    }
    function fail(id: string, message: string): bool {
        const original = pending[id];
        if (!original)
            return false;
        const record = Object.assign({}, original, {message: message, status: "failed"});
        retire(record);
        reportFailure(record);
        return true;
    }
    function check(targetId: string): void {
        const original = forTarget(targetId);
        if (!original || !original.operationId) {
            if (original)
                store(Object.assign({}, original, {checks: original.checks + 1, message: original.request.action.label + ": still waiting for confirmation"}));
            if (controller.uiActive)
                controller.refresh(false);
            return;
        }
        if (original.statusRequestId)
            return;
        const record = Object.assign({}, original, {
            checks: original.checks + 1,
            statusRequestId: backend.nextRequestId("operation-status"),
            message: original.request.action.label + ": still waiting for confirmation"
        });
        store(record);
        backend.operationStatus(record.statusRequestId, record.operationId);
    }
    // Retire only an owned read, including an empty/malformed success payload.
    // Neither a missing status nor a read error completes the pending mutation.
    function finishStatus(id: string, operation: var, error: string): bool {
        if (!id)
            return false;
        const original = Object.values(pending).find(record => record.statusRequestId === id);
        if (!original)
            return false;
        const record = Object.assign({}, original, {statusRequestId: ""});
        if (error) {
            record.checks = 10;
            record.message = "Could not confirm action status: " + error + ". Check windows before trying again.";
        }
        store(record);
        if (!error && operation?.id === record.operationId)
            apply(record.request.id, operation);
        return true;
    }
    function transportLost(message: string): void {
        for (const id of Object.keys(pending))
            fail(id, message + ". Action outcome unknown; check windows before trying again.");
    }
    function poll(): void {
        for (const record of Object.values(pending)) {
            if (record.checks < 10)
                check(record.request.result.id);
        }
    }
    Timer {
        interval: 2000
        running: Object.values(operations.pending).some(record => record.checks < 10)
        repeat: true
        onTriggered: operations.poll()
    }
}
