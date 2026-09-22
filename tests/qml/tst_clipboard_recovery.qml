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
    Component { id: paneFactory; Clip.ClipboardListPane {} }
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
        reply(controller, queryId, {history: {revision: 2, snapshot_revision: "2", total: 1, entries: [{id: "first", revision: 1, kind: "text", preview: "Original", byte_size: 8}], has_more: false}});
        compare(controller.sessionId, "new-session");
        compare(controller.filteredResults.length, 1);
        details.load();
        compare(details.editDraft, "Draft at disconnect");
        verify(details.editing && details.editDirty);
    }
    function test_nativeSearchLoadsOnlyRequestedPagesAndFencesOldQueries() {
        const controller = makeController();
        controller.refresh();
        const firstId = controller.activeHistoryQueryId;
        const entries = Array.from({length: 200}, function (_, index) { return { id: "row-" + index, revision: 1, kind: "text", preview: "Row " + index }; });
        reply(controller, firstId, {history: {snapshot_revision: "123", total: 201, offset: 0, entries: entries, next_cursor: "opaque-next", has_more: true}});
        wait(0);
        compare(controller.filteredResults.length, 200);
        compare(calls.filter(call => call.method === "clipboard.history.query").length, 1, "do not eagerly fetch the catalog");
        controller.loadMoreHistory();
        const pageId = controller.activeHistoryQueryId;
        const pageCall = calls.filter(call => call.method === "clipboard.history.query")[1];
        compare(pageCall.params.cursor, "opaque-next");
        compare(pageCall.params.fuzzy, true);
        compare(pageCall.params.offset, undefined);
        reply(controller, pageId, {history: {snapshot_revision: "123", total: 201, offset: 200, entries: [{id: "last", revision: 1, kind: "text", preview: "Last"}], has_more: false}});
        compare(controller.filteredResults.length, 201);
        compare(controller.filteredResults[200].id, "last");
        controller.filterText = "cafee";
        tryVerify(function () { return controller.activeHistoryQueryId.length > 0; });
        const query = calls.filter(call => call.method === "clipboard.history.query").slice(-1)[0];
        compare(query.params.query, "cafee");
        compare(query.params.cursor, null);
        controller.applyHistory(pageId, {snapshot_revision: "old", entries: []});
        compare(controller.historyRevision, "123", "a superseded page must not replace the current view");
    }

    function pagedController() {
        const controller = makeController();
        controller.refresh();
        const entries = Array.from({length: 200}, function (_, index) {
            return {id: "row-" + index, revision: 1, kind: "text", preview: "Row " + index, favorite: false};
        });
        reply(controller, controller.activeHistoryQueryId, {history: {
            snapshot_revision: "123", total: 400, offset: 0, entries: entries, next_cursor: "next-page"
        }});
        wait(0);
        calls = [];
        return controller;
    }
    function makePane(controller) {
        const pane = createTemporaryObject(paneFactory, testCase, {controller: controller, width: 600, height: 600});
        verify(pane !== null);
        views = views.concat([pane]);
        verify(waitForRendering(pane));
        wait(0);
        return pane;
    }
    function historyCalls() {
        return calls.filter(call => call.method === "clipboard.history.query");
    }
    function test_scrollPrefetchPreservesViewportAndSelection() {
        const controller = pagedController();
        const pane = makePane(controller);
        const list = findChild(pane, "resultListView");
        tryCompare(list, "count", 200);
        wait(0);
        compare(historyCalls().length, 0, "opening must not fetch the whole catalog");
        compare(pane.listOptionsComponent, null, "no top pagination toolbar");
        list.positionViewAtIndex(195, ListView.Beginning);
        tryCompare(controller, "loadingMoreHistory", true);
        compare(historyCalls().length, 1);
        compare(controller.selectedIndex, 0, "mouse scrolling need not change selection");
        const scrollY = list.contentY;
        verify(list.footerItem.height > 0, "show loading feedback at the bottom");
        controller.loadMoreHistory();
        compare(historyCalls().length, 1, "coalesce requests in flight");
        const entries = Array.from({length: 200}, function (_, index) {
            return {id: "row-" + (200 + index), revision: 1, kind: "text", preview: "More " + index, favorite: false};
        });
        reply(controller, controller.activeHistoryQueryId, {history: {
            snapshot_revision: "123", total: 400, offset: 200, entries: entries
        }});
        tryCompare(list, "count", 400);
        wait(0);
        compare(controller.selectedIndex, 0);
        compare(list.contentY, scrollY, "appending must not jump back to the selected row");
        compare(list.footerItem.height, 0);
        list.positionViewAtEnd();
        wait(0);
        compare(historyCalls().length, 1, "stop at cursor exhaustion");
    }
    function test_pageFailureOffersExplicitRetryWithoutLoop() {
        const controller = pagedController();
        const pane = makePane(controller);
        const list = findChild(pane, "resultListView");
        tryCompare(list, "count", 200);
        wait(0); // Let initial selection reveal settle before scrolling.
        list.positionViewAtEnd();
        tryCompare(controller, "loadingMoreHistory", true);
        reply(controller, controller.activeHistoryQueryId, {}, "Temporary read failure");
        compare(controller.historyCursor, "next-page");
        compare(controller.historyPageError, "Temporary read failure");
        compare(controller.filteredResults.length, 200);
        const retry = findChild(pane, "retryClipboardHistory");
        verify(retry.visible);
        controller.select(199);
        list.positionViewAtEnd();
        wait(100);
        compare(historyCalls().length, 1, "neither scrolling nor selection automatically retries errors");
        retry.clicked();
        compare(historyCalls().length, 2);
        compare(historyCalls()[1].params.cursor, "next-page");
        compare(controller.historyPageError, "");
        verify(controller.loadingMoreHistory);
        reply(controller, controller.activeHistoryQueryId, {history: {
            snapshot_revision: "123", total: 201, offset: 200,
            entries: [{id: "last", revision: 1, kind: "text", preview: "Last", favorite: false}]
        }});
        wait(0);
        compare(controller.filteredResults.length, 201);
        compare(controller.selectedIndex, 199);
        compare(list.footerItem.height, 0);
        compare(historyCalls().length, 2);
    }
    function test_keyboardPrefetchAndHiddenGuard() {
        const controller = pagedController();
        controller.select(195);
        wait(0);
        compare(historyCalls().length, 0);
        controller.select(196);
        tryCompare(controller, "loadingMoreHistory", true);
        compare(historyCalls().length, 1);
        reply(controller, controller.activeHistoryQueryId, {}, "Temporary read failure");
        controller.uiActive = false;
        controller.loadMoreHistory();
        compare(historyCalls().length, 1, "hidden surfaces must not page");
    }
    function test_warmReopenRetainsCursorAfterRevisionCheck() {
        const controller = pagedController();
        controller.deactivateUi();
        compare(controller.historyCursor, "next-page");
        controller.activateUi("1");
        verify(controller.revisionRequestId.length > 0);
        controller.loadMoreHistory();
        compare(historyCalls().length, 0, "validate the cached snapshot before paging");
        reply(controller, controller.revisionRequestId, {revision: {}, snapshot_revision: "123"});
        controller.loadMoreHistory();
        compare(historyCalls().length, 1);
        compare(historyCalls()[0].params.cursor, "next-page");
    }
    function test_searchChangeClearsPageErrorAndOldCursor() {
        const controller = pagedController();
        controller.loadMoreHistory();
        reply(controller, controller.activeHistoryQueryId, {}, "Temporary read failure");
        controller.filterText = "new search";
        controller.loadMoreHistory();
        compare(historyCalls().length, 1, "never retry the old query after search changes");
        tryVerify(function () { return historyCalls().length === 2; });
        compare(controller.historyPageError, "");
        compare(controller.historyCursor, "");
        compare(historyCalls()[1].params.query, "new search");
        compare(historyCalls()[1].params.cursor, null);
    }
    function test_stalePageRefreshesInsteadOfRetryingCursor() {
        const controller = pagedController();
        controller.loadMoreHistory();
        reply(controller, controller.activeHistoryQueryId, {}, "stale-cursor: history changed");
        compare(controller.historyCursor, "");
        compare(controller.historyPageError, "");
        tryVerify(function () { return historyCalls().length === 2; });
        compare(historyCalls()[1].params.cursor, null);
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
