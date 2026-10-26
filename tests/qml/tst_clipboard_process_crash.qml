pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import "../../clipboard" as Clip

// Actual Qt/controller/shared-generation acceptance. The transport is recording;
// real producer SIGKILL evidence is in clip-daemon's separate process fixture.
DaemonTestCase {
    id: testCase
    name: "ClipboardProcessCrash"
    when: windowShown
    Component { id: controllerFactory; Clip.ClipboardController {} }
    readonly property var target: ({id: "fixture", revision: 1, kind: "text", preview: "Original", byte_size: 8})

    function init() {
        failOnWarning(/.*(TypeError|Binding loop|invalid context).*/);
        clientReady = true;
        calls = [];
    }
    function make() {
        const controller = createTemporaryObject(controllerFactory, testCase);
        verify(controller !== null);
        controller.uiActive = true;
        wait(0);
        return controller;
    }
    function backend(controller) { return findChild(controller, "clipboardBackend"); }
    function session() { return Io.DaemonSessions.sessions["clip-daemon"]; }
    function lastCall(controller: var, method: string): var {
        const consumer = backend(controller).sharedConsumerId;
        const matching = calls.filter(call => call.route.consumerId === consumer && call.method === method);
        verify(matching.length > 0, "request exists: " + method);
        return matching[matching.length - 1];
    }
    function response(call, data) {
        session().client.response(call.id, {protocol: "clip-api", version: 2, ok: true, data: data}, "", call.route);
    }
    function operation(id: string, status: string, epoch: string, revision: int): var {
        return {id: id, action: "annotate", status: status, message: status,
            _publication: {epoch: epoch, revision: revision}};
    }
    function crash() {
        clientReady = false;
        session().client.transportFailed("Private daemon process lost; outcome unknown, do not replay");
    }
    function reconnect() { clientReady = true; wait(0); }
    // Omitted preview means populate it; only explicit false restores a draft.
    function select(controller: var, preview: var): void {
        controller.replaceProviderResults(controller.provider.resultsForEntries([target]), true);
        if (preview === false) return;
        controller.detailState.entryId = target.id;
        controller.detailState.entryRevision = target.revision;
        controller.detailState.value = {entry: target, text: "Original", files: []};
    }

    function test_lateOldGenerationSaveCannotConsumeFreshRetryOrPasteAuthority() {
        const controller = make();
        const peer = make();
        select(controller);
        controller.sessionId = "old-paste-session";
        const details = controller.detailState;
        verify(details.beginEdit());
        response(lastCall(controller, "clipboard.entry.edit.begin"), {edit: {id: "old-lease", value: "Original"}});
        details.updateEditDraft("Private unsaved fixture draft");
        details.pasteAfterSave = true;
        verify(details.commitEdit());
        const oldCommit = lastCall(controller, "clipboard.entry.edit.commit");
        compare(oldCommit.params.paste_session_id, "old-paste-session");
        const oldGeneration = session().generation;
        crash();
        compare(session().generation, oldGeneration + 1);
        compare(controller.sessionId, "");
        compare(peer.sessionId, "");
        compare(details.failedDrafts.fixture.draft, "Private unsaved fixture draft");
        verify(!details.pasteAfterSave);
        calls = [];
        reconnect();
        verify(calls.every(call => ["clipboard.session.begin", "clipboard.settings.get", "clipboard.history.query"].includes(call.method)), "reconnect reads/baseline only, no save/publication/capture/paste replay");
        compare(calls.filter(call => call.method === "clipboard.session.begin").length, 2, "each live consumer gets fresh authority");
        response(lastCall(controller, "clipboard.session.begin"), {session: {id: "new-session", state: "active"}});
        response(lastCall(peer, "clipboard.session.begin"), {session: {id: "peer-new-session", state: "active"}});
        select(controller, false);
        details.load();
        compare(details.editDraft, "Private unsaved fixture draft");
        verify(details.retryEdit(), "retry is explicit and obtains a fresh lease");
        response(lastCall(controller, "clipboard.entry.edit.begin"), {edit: {id: "new-lease", value: "Original"}});
        const freshCommit = lastCall(controller, "clipboard.entry.edit.commit");
        compare(freshCommit.params.edit_id, "new-lease");
        verify(!freshCommit.params.paste_session_id, "retired session's hidden/paste intent is not restored");
        verify(details.saveInFlight);
        const saved = {entry: {entry: {id: "replacement", revision: 2, kind: "text"}, text: "Private unsaved fixture draft", files: []},
            paste: {session_id: "old-paste-session", prepared: true}};
        response(oldCommit, saved); // Identical local ID, retired transport generation.
        verify(details.saveInFlight, "stale receipt cannot consume the new pending edit-commit");
        verify(backend(controller).isPending("edit-commit"));
        compare(controller.sessionId, "new-session");
        compare(peer.sessionId, "peer-new-session");
        compare(details.editDraft, "Private unsaved fixture draft");
        verify(!calls.some(call => call.method === "clipboard.session.hidden"));
        response(freshCommit, {entry: saved.entry});
        verify(!details.saveInFlight);
        verify(!backend(controller).isPending("edit-commit"));
        compare(Object.keys(details.failedDrafts).length, 0);
        verify(!calls.some(call => call.method === "clipboard.session.hidden"));
    }

    function test_oldAcceptanceAndTerminalCannotReopenOrFinishNewConsumerWork_data() {
        return [{tag: "before-ack", accepted: false, terminal: false},
            {tag: "accepted", accepted: true, terminal: false},
            {tag: "terminal-delivered", accepted: true, terminal: true}];
    }
    function test_oldAcceptanceAndTerminalCannotReopenOrFinishNewConsumerWork(data) {
        const controller = make();
        const peer = make();
        select(peer);
        verify(peer.detailState.beginEdit());
        response(lastCall(peer, "clipboard.entry.edit.begin"), {edit: {id: "peer-draft-lease", value: "Original"}});
        peer.detailState.updateEditDraft("Retained local draft");
        verify(controller.runAction("annotate", undefined, target));
        const oldCall = lastCall(controller, "clipboard.entry.action");
        if (data.accepted)
            response(oldCall, {operation: operation("old-operation", "started", "old-epoch", 1)});
        const oldConsumer = session().consumers[oldCall.route.consumerId];
        const oldSubscriptionRequest = session().client.subscriptions.find(call => call.id === oldConsumer.baseSubscriptionRequestId);
        verify(oldSubscriptionRequest !== undefined);
        session().client.response(oldSubscriptionRequest.id, {ok: true, data: {subscription: {id: "old-subscription"}}}, "", oldSubscriptionRequest.route);
        const oldEvent = {protocol: "clip-api", version: 2, stream: "clipboard.operation", event: "completed", subscription_id: "old-subscription",
            data: {operation: operation("old-operation", "completed", "old-epoch", 2)}};
        if (data.terminal) {
            session().client.eventReceived(oldEvent, oldSubscriptionRequest.route);
            verify(!controller.actionInFlight);
        }
        crash();
        verify(!controller.actionInFlight);
        compare(controller.activeOperationId, "");
        compare(peer.detailState.failedDrafts.fixture.draft, "Retained local draft");
        calls = [];
        reconnect();
        verify(calls.every(call => ["clipboard.session.begin", "clipboard.settings.get", "clipboard.history.query"].includes(call.method)));
        const freshConsumer = session().consumers[oldCall.route.consumerId];
        const freshSubscriptionRequest = session().client.subscriptions.find(call => call.id === freshConsumer.baseSubscriptionRequestId);
        verify(freshSubscriptionRequest !== undefined);
        verify(freshSubscriptionRequest.route.generation > oldSubscriptionRequest.route.generation);
        session().client.response(freshSubscriptionRequest.id, {ok: true, data: {subscription: {id: "new-subscription"}}}, "", freshSubscriptionRequest.route);
        compare(freshConsumer.baseSubscriptionId, "new-subscription");
        verify(controller.runAction("annotate", undefined, target), "only explicit new work may dispatch");
        const newCall = lastCall(controller, "clipboard.entry.action");
        response(newCall, {operation: operation("new-operation", "started", "new-epoch", 1)});
        verify(controller.actionInFlight);
        compare(controller.activeOperationId, "new-operation");
        response(oldCall, {operation: operation("old-operation", "started", "old-epoch", 1)});
        session().client.eventReceived(oldEvent, oldSubscriptionRequest.route);
        // A late old subscription acknowledgement cannot replace a fresh one.
        session().client.response(oldSubscriptionRequest.id, {ok: true, data: {subscription: {id: "old-subscription"}}}, "", oldSubscriptionRequest.route);
        verify(controller.actionInFlight);
        compare(controller.activeOperationId, "new-operation");
        compare(session().consumers[oldCall.route.consumerId].baseSubscriptionId, "new-subscription");
        compare(backend(controller).requestPolicy.operations["old-operation"], undefined);
        verify(!peer.actionInFlight);
        compare(Object.keys(backend(peer).requestPolicy.operations).length, 0);
        select(peer, false);
        peer.detailState.load();
        compare(peer.detailState.editDraft, "Retained local draft");
        verify(!calls.some(call => call.method === "clipboard.session.hidden" || call.method === "clipboard.capture.interactive"));
    }
}
