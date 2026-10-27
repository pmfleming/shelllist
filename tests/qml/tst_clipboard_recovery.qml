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
            version: 2,
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
            _history: {epoch: "fixture", revision: 2},
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
            paste: data.outcome === "missing" ? null : {session_id: data.outcome === "different" ? "unowned" : "paste-session", prepared: data.prepared, message: "Native outcome"}
        });
        compare(calls.filter(call => call.method === "clipboard.entry.action").length, 0, "no chained publication or replay");
        compare(calls.filter(call => call.method === "clipboard.session.hidden").length, data.prepared && !data.stale && !data.outcome ? 1 : 0);
        compare(details.editError, "", "saved edits are not retried for paste-preparation failure");
        verify(!details.saveInFlight);
    }

    function test_pasteKeepsOwnerAliveAfterHiding_data() {
        return [{tag: "file", action: "image-as-file"},
            {tag: "normal", action: "paste"},
            {tag: "reopened", action: "image-as-file", reopen: true},
            {tag: "disconnect", action: "image-as-file", disconnect: true},
            {tag: "failed-wait", action: "image-as-file", error: "Session cancelled"}];
    }
    function test_pasteKeepsOwnerAliveAfterHiding(data) {
        const controller = makeController();
        const backend = findChild(controller, "clipboardBackend");
        const entry = {id: "image", revision: 1, kind: "image", preview: "Image", byte_size: 8};
        controller.replaceProviderResults(controller.provider.resultsForEntries([entry]), true);
        controller.sessionId = "paste-session";
        controller.hideRequested.connect(() => controller.deactivateUi());
        const panel = createTemporaryObject(contentFactory, testCase, {controller: controller, width: 650, height: 900});
        views = views.concat([panel]);
        tryVerify(() => panel.listItem !== null);
        panel.listItem.focusList();
        keyClick(Qt.Key_Return, data.action === "image-as-file" ? Qt.ShiftModifier : Qt.NoModifier);
        const action = calls.find(call => call.method === "clipboard.entry.action");
        verify(!!action);
        compare(action.params.action, data.action);
        reply(controller, "action-" + data.action, {operation: {
            id: "paste-operation", action: data.action, status: "paste-prepared",
            _publication: {epoch: "fixture", revision: 1}
        }});
        verify(controller.uiActive, "publication alone does not hide the picker");
        reply(controller, "session-hidden", {session: {id: "paste-session", state: "hidden"}});
        verify(!controller.uiActive);
        verify(backend.active, "hiding must not cancel delayed paste through owner loss");
        compare(controller.sessionId, "");
        const waitCall = calls.find(call => call.method === "clipboard.session.wait");
        verify(!!waitCall);
        compare(waitCall.params.session_id, "paste-session");
        verify(!calls.some(call => call.method === "clipboard.session.end"));
        if (data.reopen) {
            controller.uiActive = true;
            controller.sessionId = "new-session";
        }
        if (data.disconnect) {
            backend.failSharedTransport("Disconnected during paste");
            calls = [];
            backend.transportReady();
            compare(calls.length, 0, "hidden recovery must not replay paste or wait");
        }
        reply(controller, waitCall.route.localId, {session: {id: "paste-session", state: "finished"}}, data.error);
        compare(Object.keys(backend.pasteDispatches).length, 0);
        compare(backend.active, !!data.reopen);
        compare(controller.sessionId, data.reopen ? "new-session" : "");
        if (data.error) compare(controller.status, data.error);
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
