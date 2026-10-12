pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import "../../clipboard" as Clip

DaemonTestCase {
    id: testCase
    name: "ClipboardRecovery"
    when: windowShown
    visible: true
    width: 650
    height: 900
    property var views: []
    Component {
        id: controllerFactory
        Clip.ClipboardController {}
    }
    Component { id: contentFactory; Clip.ClipboardContent {} }
    Component {
        id: paneFactory
        Clip.ClipboardListPane {}
    }
    Component {
        id: editorPanelFactory
        Ui.PanelSurface {
            id: panel
            required property Clip.ClipboardController controller
            chooserController: controller
            width: 600
            height: 800
            Clip.ClipboardDetailCards {
                anchors.fill: parent
                controller: panel.controller
            }
        }
    }
    function test_keyboardEditLeaseSavesOnlyOnExplicitCommit_data() {
        return [{tag: "tab", key: Qt.Key_Tab, modifiers: Qt.NoModifier}];
    }
    function test_keyboardEditLeaseSavesOnlyOnExplicitCommit(data) {
        const controller = makeController();
        const panel = createTemporaryObject(editorPanelFactory, testCase, {controller: controller});
        views = views.concat([panel]);
        panel.detailsNavigation.focusContent(true);
        keyClick(Qt.Key_Return);
        verify(controller.detailState.editBeginPending);
        reply(controller, "edit-begin", {edit: {id: "keyboard-lease", value: "Original"}});
        const editor = findChild(panel, "clipboardTextEditor");
        verify(editor.activeFocus && !editor.readOnly);
        calls = [];
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_X);
        compare(editor.text, "Originalx");
        wait(900); // Longer than the domain's former per-keystroke debounce.
        verify(!calls.some(call => call.method === "clipboard.entry.edit.commit"));
        compare(controller.detailState.editDraft, "Original");
        keyClick(data.key, data.modifiers);
        verify(controller.detailState.saveInFlight);
        compare(controller.detailState.committedDraft, "Originalx");
    }
    function test_escapeDiscardsClipboardDraft_data() {
        return [{tag: "fresh", failed: false}, {tag: "failed", failed: true}];
    }
    function test_escapeDiscardsClipboardDraft(data) {
        const controller = makeController();
        if (data.failed)
            failEdit(controller);
        const panel = createTemporaryObject(editorPanelFactory, testCase, {controller: controller});
        views = views.concat([panel]);
        panel.detailsNavigation.focusContent(true);
        keyClick(Qt.Key_Return);
        const editor = findChild(panel, "clipboardTextEditor");
        if (!data.failed)
            reply(controller, "edit-begin", {edit: {id: "discard-lease", value: "Original"}});
        compare(editor.text, data.failed ? "Keep this draft" : "Original");
        calls = [];
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_X);
        keyClick(Qt.Key_Escape);
        verify(panel.detailsNavigation.browsing);
        verify(!controller.detailState.editing && !controller.detailState.editDirty);
        compare(controller.detailState.editDraft, "");
        compare(controller.detailState.editError, "");
        compare(Object.keys(controller.detailState.failedDrafts).length, 0);
        verify(!calls.some(call => call.method === "clipboard.entry.edit.commit"));
        if (!data.failed)
            compare(editor.text, "Original");
        else
            compare(controller.status, "Clipboard draft discarded");
    }

    function test_compactDeleteConfirmation_data() {
        return [{tag: "escape", route: "escape", width: 480},
            {tag: "tab-return-deletes", route: "tab", width: 650}];
    }
    function test_compactDeleteConfirmation(data) {
        const controller = makeController();
        const content = createTemporaryObject(contentFactory, testCase, {
            controller: controller, width: data.width, height: 650
        });
        views = views.concat([content]);
        tryVerify(() => content.listItem !== null);
        content.listItem.focusList();
        calls = [];
        keyClick(Qt.Key_Delete);
        tryCompare(controller, "deleteConfirmationOpen", true);
        const dialog = findChild(content, "clipboardDeleteConfirmation");
        const card = findChild(dialog, "modalCard");
        const accept = findChild(dialog, "detailAction:accept");
        const reject = findChild(dialog, "detailAction:reject");
        tryCompare(reject, "activeFocus", true);
        verify(!content.navigationEnabled);
        compare(dialog.detail, "");
        verify(!dialog.actionSummaryVisible);
        verify(dialog.Accessible.description.indexOf("permanently removed") >= 0);
        verify(card.width <= 520 && card.height < 180, "compact confirmation uses less space");
        const cancelCenter = reject.mapToItem(card, reject.width / 2, reject.height / 2);
        const deleteCenter = accept.mapToItem(card, accept.width / 2, accept.height / 2);
        compare(cancelCenter.y, deleteCenter.y);
        verify(cancelCenter.x + reject.width / 2 < deleteCenter.x - accept.width / 2);
        compare(calls.length, 0, "opening the confirmation cannot delete");
        if (data.route === "escape")
            keyClick(Qt.Key_Escape);
        else {
            keyClick(Qt.Key_Tab);
            verify(accept.activeFocus);
            keyClick(Qt.Key_Return);
        }
        tryCompare(controller, "deleteConfirmationOpen", false);
        const actions = calls.filter(call => call.method === "clipboard.entry.action");
        const deleting = data.route === "tab";
        compare(actions.length, deleting ? 1 : 0);
        if (deleting) {
            compare(actions[0].params.action, "delete");
            compare(actions[0].params.entry_id, "first");
            compare(actions[0].params.revision, 1);
        } else {
            verify(content.listItem.listFocused, "cancellation restores list focus");
        }
    }

    function test_bulkAndWipeCompactConfirmations_data() {
        return [{tag: "selected-one", count: 1}, {tag: "selected-many", count: 3}, {tag: "wipe", count: 0}];
    }
    function test_bulkAndWipeCompactConfirmations(data) {
        const controller = makeController();
        const content = createTemporaryObject(contentFactory, testCase, {controller: controller, width: 560, height: 650});
        views = views.concat([content]);
        tryVerify(() => content.listItem !== null);
        content.listItem.focusList();
        const entries = {};
        for (let i = 0; i < data.count; ++i) entries["entry-" + i] = {id: "entry-" + i, revision: i + 1};
        controller.multiSelectedIds = entries;
        const open = () => {
            if (data.count) controller.requestBulkDelete();
            else controller.applyWipeChallenge({id: "owned-wipe"});
        };
        calls = [];
        open();
        const modal = findChild(content, data.count ? "clipboardBulkDeleteConfirmation" : "clipboardWipeConfirmation");
        tryCompare(findChild(modal, "detailAction:reject"), "activeFocus", true);
        verify(modal.compactPresentation && !modal.actionSummaryVisible);
        verify(!findChild(modal, "modalDetail").visible);
        verify(modal.Accessible.description.includes("permanently"));
        compare(modal.title, data.count ? "Delete " + data.count + " clipboard " + (data.count === 1 ? "entry?" : "entries?") : "Clear all clipboard history?");
        compare(calls.length, 0);
        keyClick(Qt.Key_Escape);
        verify(!modal.visible);
        compare(calls.length, 0, "cancel never commits deletion");
        open();
        tryCompare(findChild(modal, "detailAction:reject"), "activeFocus", true);
        keyClick(Qt.Key_Tab);
        verify(findChild(modal, "detailAction:accept").activeFocus);
        keyClick(Qt.Key_Return);
        if (data.count) {
            const write = calls.find(call => call.method === "clipboard.entries.delete");
            verify(!!write);
            compare(write.params.entries, Object.values(entries).map(e => ({entry_id: e.id, revision: e.revision})));
        } else {
            const write = calls.find(call => call.method === "clipboard.history.wipe.commit");
            verify(!!write);
            compare(write.params, {challenge_id: "owned-wipe", response: "WIPE"});
        }
    }

    function init() {
        failOnWarning(/.*(TypeError|Binding loop|invalid context).*/);
    }
    function cleanup() {
        for (const view of views)
            view.destroy();
        views = [];
        wait(0);
    }
    function makeController() {
        const controller = createTemporaryObject(controllerFactory, testCase);
        verify(controller !== null);
        controller.uiActive = true;
        wait(0);
        findChild(controller, "clipboardBackend").pending = ({});
        const entries = [
            {
                id: "first",
                revision: 1,
                kind: "text",
                preview: "Original",
                favorite: false,
                byte_size: 8
            }
        ];
        controller.replaceProviderResults(controller.provider.resultsForEntries(entries), true);
        controller.detailState.entryId = "first";
        controller.detailState.entryRevision = 1;
        controller.detailState.value = {
            entry: entries[0],
            text: "Original",
            files: []
        };
        calls = [];
        return controller;
    }
    function reply(controller, id, data, error) {
        findChild(controller, "clipboardBackend").acceptSharedResponse(id, {
            protocol: "clip-api",
            version: 1,
            ok: !error,
            data: data || {},
            error: error ? {
                message: error
            } : undefined
        }, "");
    }
    function failEdit(controller) {
        const details = controller.detailState;
        verify(details.beginEdit());
        reply(controller, "edit-begin", {
            edit: {
                id: "lease-1",
                value: "Original"
            }
        });
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
        reply(controller, "edit-begin", {
            edit: {
                id: "lease-1",
                value: "Original"
            }
        });
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
        reply(controller, "session-begin", {
            session: {
                id: "new-session",
                state: "active"
            }
        });
        const queryId = controller.activeHistoryQueryId;
        reply(controller, queryId, {
            history: {
                revision: 2,
                snapshot_revision: "2",
                total: 1,
                entries: [
                    {
                        id: "first",
                        revision: 1,
                        kind: "text",
                        preview: "Original",
                        byte_size: 8
                    }
                ],
                has_more: false
            }
        });
        compare(controller.sessionId, "new-session");
        compare(controller.filteredResults.length, 1);
        details.load();
        compare(details.editDraft, "Draft at disconnect");
        verify(details.editing && details.editDirty);
        controller.uiActive = false;
        calls = [];
        backend.transportReady();
        compare(calls.length, 0, "hidden consumers do not open a session on recovery");
    }
    function test_nativeSearchLoadsOnlyRequestedPagesAndFencesOldQueries() {
        const controller = makeController();
        controller.refresh();
        const firstId = controller.activeHistoryQueryId;
        const entries = Array.from({
            length: 200
        }, function (_, index) {
            return {
                id: "row-" + index,
                revision: 1,
                kind: "text",
                preview: "Row " + index
            };
        });
        reply(controller, firstId, {
            history: {
                snapshot_revision: "123",
                total: 201,
                offset: 0,
                entries: entries,
                next_cursor: "opaque-next",
                has_more: true
            }
        });
        wait(0);
        compare(controller.filteredResults.length, 200);
        compare(calls.filter(call => call.method === "clipboard.history.query").length, 1, "do not eagerly fetch the catalog");
        controller.loadMoreHistory();
        const pageId = controller.activeHistoryQueryId;
        const pageCall = calls.filter(call => call.method === "clipboard.history.query")[1];
        compare(pageCall.params.cursor, "opaque-next");
        compare(pageCall.params.fuzzy, true);
        compare(pageCall.params.offset, undefined);
        reply(controller, pageId, {
            history: {
                snapshot_revision: "123",
                total: 201,
                offset: 200,
                entries: [
                    {
                        id: "last",
                        revision: 1,
                        kind: "text",
                        preview: "Last"
                    }
                ],
                has_more: false
            }
        });
        compare(controller.filteredResults.length, 201);
        compare(controller.filteredResults[200].id, "last");
        controller.filterText = "cafee";
        tryVerify(function () {
            return controller.activeHistoryQueryId.length > 0;
        });
        const query = calls.filter(call => call.method === "clipboard.history.query").slice(-1)[0];
        compare(query.params.query, "cafee");
        compare(query.params.cursor, null);
        controller.applyHistory(pageId, {
            snapshot_revision: "old",
            entries: []
        });
        compare(controller.historyRevision, "123", "a superseded page must not replace the current view");
    }

    function pagedController() {
        const controller = makeController();
        controller.refresh();
        const entries = Array.from({
            length: 200
        }, function (_, index) {
            return {
                id: "row-" + index,
                revision: 1,
                kind: "text",
                preview: "Row " + index,
                favorite: false
            };
        });
        reply(controller, controller.activeHistoryQueryId, {
            history: {
                snapshot_revision: "123",
                total: 400,
                offset: 0,
                entries: entries,
                next_cursor: "next-page"
            }
        });
        wait(0);
        calls = [];
        return controller;
    }
    function makePane(controller) {
        const pane = createTemporaryObject(paneFactory, testCase, {
            controller: controller,
            width: 600,
            height: 600
        });
        verify(pane !== null);
        views = views.concat([pane]);
        verify(waitForRendering(pane));
        wait(0);
        return pane;
    }
    function historyCalls() {
        return calls.filter(call => call.method === "clipboard.history.query");
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
        reply(controller, controller.activeHistoryQueryId, {
            history: {
                snapshot_revision: "123",
                total: 201,
                offset: 200,
                entries: [
                    {
                        id: "last",
                        revision: 1,
                        kind: "text",
                        preview: "Last",
                        favorite: false
                    }
                ]
            }
        });
        wait(0);
        compare(controller.filteredResults.length, 201);
        compare(controller.selectedIndex, 199);
        compare(list.footerItem.height, 0);
        compare(historyCalls().length, 2);
    }
    function test_stalePageRefreshesInsteadOfRetryingCursor() {
        const controller = pagedController();
        controller.loadMoreHistory();
        reply(controller, controller.activeHistoryQueryId, {}, "stale-cursor: history changed");
        compare(controller.historyCursor, "");
        compare(controller.historyPageError, "");
        tryVerify(function () {
            return historyCalls().length === 2;
        });
        compare(historyCalls()[1].params.cursor, null);
    }

    function test_saveAndPasteUsesOneWriteAndKeepsHiddenHandshake_data() {
        return [{tag: "prepared", prepared: true, stale: false},
            {tag: "publication-failed", prepared: false, stale: false},
            {tag: "reopened-session", prepared: true, stale: true}];
    }
    function test_saveAndPasteUsesOneWriteAndKeepsHiddenHandshake(data) {
        const controller = makeController();
        controller.sessionId = "paste-session";
        const panel = createTemporaryObject(contentFactory, testCase, {controller: controller, width: 650, height: 900});
        views = views.concat([panel]);
        const details = controller.detailState;
        verify(details.beginEdit());
        reply(controller, "edit-begin", {edit: {id: "paste-lease", value: "Original"}});
        details.updateEditDraft("Saved before paste");
        tryVerify(() => panel.listItem !== null);
        panel.listItem.focusList();
        keyClick(Qt.Key_Return);
        const commit = calls.find(call => call.method === "clipboard.entry.edit.commit");
        verify(!!commit, JSON.stringify(calls) + " / " + details.editing + " / " + details.editDirty + " / " + details.entryId);
        compare(commit.params.paste_session_id, "paste-session");
        if (data.stale) controller.sessionId = "reopened";
        reply(controller, "edit-commit", {
            entry: {entry: {id: "replacement", revision: 2, kind: "text"}, text: "Saved before paste", files: []},
            paste: {session_id: "paste-session", prepared: data.prepared, message: "Native outcome"}
        });
        compare(calls.filter(call => call.method === "clipboard.entry.action").length, 0, "no chained publication or replay");
        compare(calls.filter(call => call.method === "clipboard.session.hidden").length, data.prepared && !data.stale ? 1 : 0);
        compare(details.editError, "", "saved edits are not retried for paste-preparation failure");
        verify(!details.saveInFlight);
    }

    function test_failedSaveRetriesWithFreshLeaseAndKeepsVisibleDraft_data() {
        return [{tag: "enter", key: Qt.Key_Return}];
    }
    function test_failedSaveRetriesWithFreshLeaseAndKeepsVisibleDraft(data) {
        const controller = makeController();
        const details = controller.detailState;
        failEdit(controller);
        const pane = makePane(controller);
        pane.feedbackScope = pane;
        const feedback = findChild(pane, "feedbackText");
        compare(feedback.text, "Disk full");
        const panel = createTemporaryObject(editorPanelFactory, testCase, {controller: controller});
        views = views.concat([panel]);
        verify(findChild(panel, "retryClipboardEdit") === null);
        verify(findChild(panel, "discardClipboardEdit") === null);
        panel.detailsNavigation.focusContent(true);
        keyClick(Qt.Key_Return);
        const editor = findChild(panel, "clipboardTextEditor");
        compare(editor.text, "Keep this draft");
        verify(!editor.readOnly);
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_X);
        const previousCalls = calls.length;
        wait(700);
        compare(calls.length, previousCalls); // No automatic retry loop after a failure.
        compare(details.editDraft, "Keep this draft", "reopened edits stay field-local until save");
        keyClick(data.key);
        compare(calls[calls.length - 1].method, "clipboard.entry.edit.begin");
        compare(calls[calls.length - 1].params.entry_id, "first");
        compare(calls[calls.length - 1].params.revision, 1);
        verify(!details.retryEdit());
        reply(controller, "edit-begin", {
            edit: {
                id: "lease-2",
                value: "Original"
            }
        });
        compare(calls[calls.length - 1].method, "clipboard.entry.edit.commit");
        compare(calls[calls.length - 1].params.edit_id, "lease-2");
        compare(calls[calls.length - 1].params.value, "Keep this draftx");
        reply(controller, "edit-commit", {
            entry: {
                entry: {
                    id: "replacement",
                    revision: 2,
                    kind: "text"
                },
                text: "Keep this draftx",
                files: []
            }
        });
        compare(details.editError, "");
        compare(Object.keys(details.failedDrafts).length, 0);
        compare(editor.text, "Keep this draftx");
        verify(!details.saveInFlight);
        compare(feedback.text, "Clipboard text saved");
    }
    function test_failedDraftSurvivesReloadAndConflictUntilDiscarded() {
        const controller = makeController();
        const details = controller.detailState;
        verify(details.beginEdit());
        reply(controller, "edit-begin", {edit: {id: "lease-1", value: "Original"}});
        details.updateEditDraft("Keep this draft");
        verify(details.commitEdit());
        details.clear();
        reply(controller, "edit-commit", {}, "Disk full");
        details.load();
        compare(details.editDraft, "Keep this draft", "a late failure must survive leaving the editor");
        verify(details.editing && details.editDirty);
        verify(details.retryEdit());
        reply(controller, "edit-begin", {}, "Entry changed elsewhere");
        compare(details.editDraft, "Keep this draft");
        verify(details.editing && details.editDirty && !details.editBeginPending);
        compare(details.editError, "Entry changed elsewhere");
        const panel = createTemporaryObject(editorPanelFactory, testCase, {controller: controller});
        views = views.concat([panel]);
        panel.detailsNavigation.focusContent(true);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Escape);
        verify(!details.editing && !details.editDirty);
        compare(details.editError, "");
        compare(Object.keys(details.failedDrafts).length, 0);
    }
}
