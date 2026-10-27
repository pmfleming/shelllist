import Shelllist.Io as Io
import "ClipApi.js" as ClipApi

Io.DaemonBackend {
    id: clipboardBackend
    required property ClipboardController controller
    objectName: "clipboardBackend"
    daemonName: "clip-daemon"
    expectedProtocol: ClipApi.protocol
    expectedVersion: ClipApi.version
    streams: ClipApi.subscribedStreams
    requestPolicy: Io.ClipboardStateRecovery {
        backend: clipboardBackend
        onHistoryInvalidated: clipboardBackend.controller.handleHistoryChanged(undefined)
        onReadDiscarded: function(id) { clipboardBackend.controller.discardHistoryRead(id); }
        onOperationUncertain: function(id, message) { clipboardBackend.controller.handleOperationUncertain(id, message); }
    }
    // Both annotation and delayed paste outlive the picker. Disconnecting their
    // owner cancels them, so hiding alone must not retire this connection.
    property var pasteDispatches: ({})
    active: controller.uiActive || controller.backgroundOperationInFlight || Object.keys(pasteDispatches).length > 0
    readonly property var eventHandlers: {
        const handlers = ({});
        handlers[ClipApi.streams.history] = function (event) {
            controller.handleHistoryChanged(event.data ? event.data.history_revision : undefined);
        };
        handlers[ClipApi.streams.current] = handlers[ClipApi.streams.history];
        handlers[ClipApi.streams.capture] = function () {
            getSettings();
        };
        handlers[ClipApi.streams.operation] = function (event) {
            const operation = event.data && event.data.operation;
            if (operation) {
                controller.applyOperation(operation);
                if (operation.status !== "started")
                    controller.scheduleRefresh();
            }
        };
        return handlers;
    }

    function finish(id: string, envelope: var, transportError: string): void {
        const error = responseError(envelope, transportError, "Clipboard operation failed");
        if (finishPasteWait(id, envelope ? envelope.data : null, error))
            return;
        if (error) {
            controller.handleFailure(id, error);
            return;
        }
        applyResponse(id, envelope.data || ({}));
    }

    function applyResponse(id: string, data: var): void {
        const handlers = ({
                history: function (value) {
                    controller.applyHistory(id, value);
                },
                revision: function (value) {
                    controller.applyRevision(id, data.snapshot_revision);
                },
                session: controller.applySession,
                entry: function (value) {
                    if (id === "edit-commit")
                        controller.detailState.applyEditCommit(value, data.paste);
                    else
                        controller.detailState.applyDetails(id, value);
                },
                thumbnail: function (value) {
                    controller.detailState.applyThumbnail(id, value);
                },
                operation: controller.applyOperation,
                challenge: controller.applyWipeChallenge,
                edit: function (value) {
                    controller.detailState.applyEdit(id, value);
                },
                settings: controller.applySettings,
                capture: controller.applyCapture
            });
        Object.keys(data).forEach(function (key) {
            if (handlers[key])
                handlers[key](data[key]);
        });
    }

    function revision(id: string): bool {
        return call(id, ClipApi.methods.historyRevision, {});
    }
    function query(id: string, text: string, generation: int, limit: int, cursor: string): bool {
        return call(id, ClipApi.methods.historyQuery, {
            query: text,
            generation: generation,
            limit: limit,
            fuzzy: true,
            cursor: cursor || null
        });
    }
    function details(id: string, entry: var): bool {
        return call(id, ClipApi.methods.entryDetails, {
            entry_id: entry.id,
            revision: entry.revision
        });
    }
    function thumbnail(id: string, entry: var): bool {
        return call(id, ClipApi.methods.entryThumbnail, {
            entry_id: entry.id,
            revision: entry.revision,
            edge: 640
        });
    }
    function beginSession(): bool {
        return call("session-begin", ClipApi.methods.sessionBegin, {});
    }
    function hideSession(sessionId: string): bool {
        return call("session-hidden", ClipApi.methods.sessionHidden, {
            session_id: sessionId
        });
    }
    function waitForPaste(sessionId: string): void {
        const id = nextRequestId("paste-wait");
        pasteDispatches = Object.assign({}, pasteDispatches, {[id]: sessionId});
        if (!call(id, ClipApi.methods.sessionWait, {session_id: sessionId}))
            finishPasteWait(id, null, "Paste dispatch outcome is unknown; paste manually if needed");
    }
    function finishPasteWait(id: string, data: var, error: string): bool {
        if (!id.startsWith("paste-wait-"))
            return false;
        const sessionId = pasteDispatches[id];
        if (!sessionId)
            return true; // A retired receipt must not affect a reopened picker.
        if (error || data?.session?.id !== sessionId || data?.session?.state !== "finished")
            controller.status = error || "Paste dispatch outcome is unknown; paste manually if needed";
        const next = Object.assign({}, pasteDispatches);
        delete next[id];
        pasteDispatches = next;
        return true;
    }
    function endSession(sessionId: string): bool {
        return call("session-end", ClipApi.methods.sessionEnd, {
            session_id: sessionId
        });
    }
    function action(id: string, entry: var, actionName: string, sessionId: string, fileIndex: var): bool {
        return call(id, ClipApi.methods.entryAction, {
            entry_id: entry.id,
            revision: entry.revision,
            action: actionName,
            session_id: sessionId || null,
            file_index: fileIndex === undefined ? null : fileIndex
        });
    }
    function deleteEntries(id: string, entries: var): bool {
        return call(id, ClipApi.methods.entriesDelete, {
            entries: entries
        });
    }
    function beginEdit(entry: var): bool {
        return call("edit-begin", ClipApi.methods.editBegin, {
            entry_id: entry.id,
            revision: entry.revision
        });
    }
    function commitEdit(editId: string, value: string, pasteSessionId: string): bool {
        return call("edit-commit", ClipApi.methods.editCommit, {
            edit_id: editId,
            value: value,
            paste_session_id: pasteSessionId || null
        });
    }
    function cancelEdit(editId: string): bool {
        return call("edit-cancel", ClipApi.methods.editCancel, {
            edit_id: editId
        });
    }
    function getSettings(): bool {
        return call("settings-get", ClipApi.methods.settingsGet, {});
    }
    function captureScreenshot(x: int, y: int, width: int, height: int): bool {
        return call("capture-screenshot", ClipApi.methods.captureScreenshot, {
            x: x,
            y: y,
            width: width,
            height: height
        });
    }
    function prepareWipe(): bool {
        return call("wipe-prepare", ClipApi.methods.wipePrepare, {});
    }
    function commitWipe(challengeId: string): bool {
        return call("wipe-commit", ClipApi.methods.wipeCommit, {
            challenge_id: challengeId,
            response: "WIPE"
        });
    }
    function cancelOperation(operationId: string): bool {
        return cancelWithId(operationId, "cancel-operation-" + operationId);
    }

    onResponseReceived: function (id, envelope, transportError) {
        finish(id, envelope, transportError);
    }
    onEventGapDetected: function (stream) {
        controller.handleEventGap(stream);
        if (stream === ClipApi.streams.capture)
            getSettings();
    }
    onEventReceived: function (event) {
        if (event.event === "subscribed")
            return;
        routeEvent(event, eventHandlers);
    }
    onSendFailed: function (id, message) {
        // A failed status read says nothing about the accepted effect. Its
        // recovery policy already reports uncertainty, not "effect not sent".
        if (!finishPasteWait(id, null, message) && !id.startsWith("clip-status-"))
            controller.handleFailure(id, message);
    }
    onTransportFailed: function (message) {
        pasteDispatches = ({});
        controller.handleTransportFailure(message);
    }
    onTransportReady: controller.handleTransportReady()
}
