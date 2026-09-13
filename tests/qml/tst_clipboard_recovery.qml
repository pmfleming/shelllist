pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Io as Io
import "../../clipboard" as Clip

TestCase {
    id: testCase
    name: "ClipboardRecovery"
    when: windowShown
    visible: true
    width: 650
    height: 900
    property var calls: []
    property var views: []
    property var originalFactory
    property var originalSessions

    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: true
            property bool recoverProtocolErrors: false
            signal response(string id, var envelope, string transportError)
            signal eventReceived(var event)
            signal transportFailed(string message)
            function call(id, method, params) { testCase.calls = testCase.calls.concat([{id: id, method: method, params: params}]); }
            function subscribeExtra(id, streams) {}
            function cancel(id, requestId) {}
            function release(id, route) {}
        }
    }
    Component { id: controllerFactory; Clip.ClipboardController {} }
    Component { id: cardsFactory; Clip.ClipboardDetailCards {} }
    function initTestCase() {
        originalFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.sessions = ({});
        Io.DaemonSessions.clientFactory = clientFactory;
    }
    function cleanupTestCase() {
        for (const session of Object.values(Io.DaemonSessions.sessions)) session.client.destroy();
        Io.DaemonSessions.sessions = originalSessions;
        Io.DaemonSessions.clientFactory = originalFactory;
    }
    function init() {
        failOnWarning(/.*(TypeError|Binding loop|invalid context).*/);
    }
    function cleanup() {
        for (const view of views) view.destroy();
        views = [];
        wait(0);
    }
    function makeCards(controller) {
        const cards = createTemporaryObject(cardsFactory, testCase, {controller: controller, width: 600, height: 800});
        views = views.concat([cards]);
        return cards;
    }
    function makeController() {
        const controller = createTemporaryObject(controllerFactory, testCase);
        verify(controller !== null);
        controller.uiActive = true;
        wait(0);
        findChild(controller, "clipboardBackend").pending = ({});
        const entries = [{id: "first", revision: 1, kind: "text", preview: "Original", byte_size: 8}];
        controller.replaceProviderResults(controller.provider.resultsForEntries(entries), true);
        controller.detailState.entryId = "first";
        controller.detailState.entryRevision = 1;
        controller.detailState.value = {entry: entries[0], text: "Original", files: []};
        calls = [];
        return controller;
    }
    function reply(controller, id, data, error) {
        findChild(controller, "clipboardBackend").acceptSharedResponse(id,
            {protocol: "clip-api", version: 1, ok: !error, data: data || {}, error: error ? {message: error} : undefined}, "");
    }
    function failEdit(controller) {
        const details = controller.detailState;
        verify(details.beginEdit());
        reply(controller, "edit-begin", {edit: {id: "lease-1", value: "Original"}});
        details.updateEditDraft("Keep this draft");
        verify(details.commitEdit());
        reply(controller, "edit-commit", {}, "Disk full");
        verify(details.editing && details.editDirty && !details.saveInFlight);
        verify(!controller.actionInFlight);
        compare(details.editDraft, "Keep this draft");
    }
    function test_transportRecoveryReloadsVisibleClipboardWithoutReplayingSave() {
        const controller = makeController();
        const details = controller.detailState;
        const backend = findChild(controller, "clipboardBackend");
        verify(details.beginEdit());
        reply(controller, "edit-begin", {edit: {id: "lease-1", value: "Original"}});
        details.updateEditDraft("Draft at disconnect");
        verify(details.commitEdit());
        backend.failSharedTransport("Disconnected");
        compare(controller.filteredResults.length, 0);
        compare(controller.sessionId, "");
        compare(details.failedDrafts.first.draft, "Draft at disconnect");
        calls = [];
        backend.transportReady();
        backend.transportReady(); // Pending recovery requests are coalesced.
        compare(calls.length, 3);
        verify(calls.some(call => call.method === "clipboard.session.begin"));
        verify(calls.some(call => call.method === "clipboard.settings.get"));
        verify(calls.some(call => call.method === "clipboard.history.query"));
        verify(!calls.some(call => call.method === "clipboard.entry.edit.commit"));
        reply(controller, "session-begin", {session: {id: "new-session", state: "active"}});
        const queryId = controller.activeHistoryQueryId;
        reply(controller, queryId, {history: {revision: 2, entries: [{id: "first", revision: 1, kind: "text", preview: "Original", byte_size: 8}], has_more: false}});
        compare(controller.sessionId, "new-session");
        compare(controller.filteredResults.length, 1);
        details.load();
        compare(details.editDraft, "Draft at disconnect");
        verify(details.editing && details.editDirty);
    }
    function test_hiddenTransportReadyDoesNotOpenClipboardSession() {
        const controller = makeController();
        controller.uiActive = false;
        calls = [];
        findChild(controller, "clipboardBackend").transportReady();
        compare(calls.length, 0);
    }
    function test_failedSaveRetriesWithFreshLeaseAndKeepsVisibleDraft() {
        const controller = makeController();
        const details = controller.detailState;
        failEdit(controller);
        const cards = makeCards(controller);
        const editor = findChild(cards, "clipboardTextEditor");
        compare(editor.text, "Keep this draft");
        verify(!editor.readOnly);
        details.updateEditDraft("Updated failed draft");
        const previousCalls = calls.length;
        wait(700);
        compare(calls.length, previousCalls); // No automatic retry loop after a failure.
        const retry = findChild(cards, "retryClipboardEdit");
        verify(retry.visible && retry.enabled);
        retry.clicked();
        compare(calls[calls.length - 1].method, "clipboard.entry.edit.begin");
        compare(calls[calls.length - 1].params.entry_id, "first");
        compare(calls[calls.length - 1].params.revision, 1);
        verify(!details.retryEdit());
        reply(controller, "edit-begin", {edit: {id: "lease-2", value: "Original"}});
        compare(calls[calls.length - 1].method, "clipboard.entry.edit.commit");
        compare(calls[calls.length - 1].params.edit_id, "lease-2");
        compare(calls[calls.length - 1].params.value, "Updated failed draft");
        reply(controller, "edit-commit", {entry: {entry: {id: "replacement", revision: 2, kind: "text"}, text: "Updated failed draft", files: []}});
        compare(details.editError, "");
        compare(Object.keys(details.failedDrafts).length, 0);
        compare(editor.text, "Updated failed draft");
        verify(!details.saveInFlight);
    }
    function test_lateCommitFailureDoesNotLoseDraftAfterLeavingEditor() {
        const controller = makeController();
        const details = controller.detailState;
        verify(details.beginEdit());
        reply(controller, "edit-begin", {edit: {id: "lease-1", value: "Original"}});
        details.updateEditDraft("Draft sent before leaving");
        verify(details.commitEdit());
        details.clear();
        reply(controller, "edit-commit", {}, "Disk full");
        details.load();
        compare(details.editDraft, "Draft sent before leaving");
        verify(details.editing && details.editDirty);
    }
    function test_failedDraftSurvivesReloadAndConflictUntilDiscarded() {
        const controller = makeController();
        const details = controller.detailState;
        failEdit(controller);
        details.clear();
        details.load();
        compare(details.editDraft, "Keep this draft");
        verify(details.editing && details.editDirty);
        verify(details.retryEdit());
        reply(controller, "edit-begin", {}, "Entry changed elsewhere");
        compare(details.editDraft, "Keep this draft");
        verify(details.editing && details.editDirty && !details.editBeginPending);
        compare(details.editError, "Entry changed elsewhere");
        const cards = makeCards(controller);
        findChild(cards, "discardClipboardEdit").clicked();
        verify(!details.editing && !details.editDirty);
        compare(details.editError, "");
        compare(Object.keys(details.failedDrafts).length, 0);
    }
}
