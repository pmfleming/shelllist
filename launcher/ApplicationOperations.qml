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
    property var feedback: ({})
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
        const next = {};
        entries.concat([[targetId, record]]).slice(-64).forEach(entry => next[entry[0]] = entry[1]);
        feedback = next;
    }
    function store(record: var): void {
        pending = Object.assign({}, pending, {[record.request.id]: record});
        publish(record);
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
            message: request.action.label + "…", awaitingWindows: false, windowChecks: 0
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
        const original = pending[responseId] || Object.values(pending).find(record => record.operationId && record.operationId === operation.id);
        if (!original)
            return; // An event before admission is recovered with an owned status read.
        const transition = Lifecycle.operationTransition(original.request, original.request.result.id, original.operationId, responseId, operation);
        if (!transition)
            return;
        const record = Object.assign({}, original, {operationId: operation.id, status: transition.status, checks: original.operationId ? original.checks : 0});
        const closing = Presentation.isCloseAction(record.request.actionId);
        if (transition.stage === "active") {
            record.message = record.request.action.label + (record.checks >= 3 ? ": still waiting for confirmation" : "…");
            // A running operation with a launch receipt has passed checked
            // process/D-Bus handoff; window placement may still take seconds.
            store(record);
            if (!closing && operation.launch_backend && operation.launch_scope) {
                handOff(record);
                store(record);
            }
            return;
        }
        const completed = transition.status === "completed";
        record.awaitingWindows = completed && closing;
        record.message = record.awaitingWindows ? "Close requested; waiting for windows to close" : (operation.message || "Application action " + transition.status);
        if (completed && !closing)
            handOff(record);
        retire(record);
        if (!completed)
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
    function applyStatus(id: string, operation: var): void {
        const original = Object.values(pending).find(record => record.statusRequestId === id);
        if (!original)
            return;
        const record = Object.assign({}, original, {statusRequestId: ""});
        store(record);
        if (operation && operation.id === record.operationId)
            apply(record.request.id, operation);
    }
    function statusFailed(id: string, message: string): bool {
        const original = Object.values(pending).find(record => record.statusRequestId === id);
        if (!original)
            return false;
        store(Object.assign({}, original, {
            statusRequestId: "", checks: 10,
            message: "Could not confirm action status: " + message + ". Check windows before trying again."
        }));
        return true;
    }
    function reconcile(applications: var): void {
        const next = Object.assign({}, feedback);
        for (const targetId of Object.keys(next)) {
            const record = next[targetId];
            if (!record.awaitingWindows || busy(targetId))
                continue;
            const application = applications.find(app => app.id === targetId);
            // A filtered/paginated catalog does not prove an absent app closed.
            if (!application) {
                next[targetId] = Object.assign({}, record, {windowChecks: record.windowChecks + 1});
                continue;
            }
            const remaining = (application.instances || []).filter(window => record.windowIds.includes(window.id));
            next[targetId] = Object.assign({}, record, {
                awaitingWindows: remaining.length > 0,
                windowChecks: record.windowChecks + 1,
                message: remaining.length > 0 ? "Close requested; " + remaining.length + (remaining.length === 1 ? " window is still open. Focus it to check for a save prompt." : " windows are still open. Focus a window to check for a save prompt.") : "Requested windows closed"
            });
        }
        feedback = next;
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
