pragma ComponentBehavior: Bound

import QtQuick
import "../../clipboard" as Clip

DaemonTestCase {
    id: testCase
    name: "ClipboardPreview"
    when: windowShown
    visible: true
    width: 1150
    height: 800
    property var panels: []

    Component {
        id: controllerFactory
        Clip.ClipboardController {}
    }
    Component {
        id: panelFactory
        Clip.ClipboardContent {
            width: testCase.width
            height: testCase.height
        }
    }

    function init() {
        failOnWarning(/.*/);
        calls = [];
    }
    function cleanup() {
        for (const panel of panels)
            panel.destroy();
        panels = [];
        wait(0);
    }
    function entry(id, kind, revision) {
        return {id: id, revision: revision || 1, kind: kind || "text", preview: id, mime: "text/plain", byte_size: 16, favorite: false, current: false};
    }
    function makeController(entries) {
        const controller = createTemporaryObject(controllerFactory, testCase);
        verify(controller !== null);
        controller.uiActive = true;
        wait(0);
        findChild(controller, "clipboardBackend").pending = ({});
        controller.replaceProviderResults(controller.provider.resultsForEntries(entries), true);
        calls = [];
        return controller;
    }
    function makePanel(controller) {
        const panel = createTemporaryObject(panelFactory, testCase, {controller: controller});
        verify(panel !== null);
        panels = panels.concat([panel]);
        tryVerify(() => !!panel.listItem);
        panel.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => !!panel.detailsItem);
        tryCompare(controller, "detailsExpansionProgress", 1);
        verify(controller.detailsOpen);
        return panel;
    }
    function reply(controller, id, data) {
        findChild(controller, "clipboardBackend").acceptSharedResponse(id, {
            protocol: "clip-api", version: 1, ok: true, data: data
        }, "");
    }
    function detailsReply(controller, target, text) {
        tryVerify(() => controller.detailState.requestId.length > 0);
        reply(controller, controller.detailState.requestId, {
            entry: {entry: target, text: text === undefined ? target.id : text, files: []}
        });
    }
    function thumbnailReply(controller, target) {
        verify(controller.detailState.thumbnailRequestId.length > 0);
        reply(controller, controller.detailState.thumbnailRequestId, {thumbnail: {
            entry_id: target.id, revision: target.revision,
            path: Qt.resolvedUrl("fixtures/media-cover.svg").toString().replace("file://", "")
        }});
    }
    function previewCalls() {
        return calls.filter(call => call.route.localId.indexOf("details-") === 0 || call.route.localId.indexOf("thumbnail-") === 0);
    }

    function test_keyboardKeepsLayoutAndUsesWarmCache() {
        const entries = [entry("first"), entry("second"), entry("third")];
        const controller = makeController(entries);
        const panel = makePanel(controller);
        detailsReply(controller, entries[0]);
        const tabs = findChild(panel, "clipboardDetailsTabs");
        const card = findChild(panel, "clipboardDataCard");
        const editor = findChild(panel, "clipboardTextEditor");
        const message = findChild(panel, "clipboardPreviewMessage");
        const geometry = [tabs.y, tabs.height, card.y, card.height, panel.detailsItem.headerHeight];
        verify(tabs.visible && card.visible && editor.visible);
        calls = [];

        keyClick(Qt.Key_Down);
        compare(controller.selectedEntry.id, "second");
        verify(controller.detailsOpen && panel.listItem.listFocused);
        verify(controller.detailState.loading, "debounce is loading, not a blank state");
        compare(controller.detailState.value, null);
        verify(tabs.visible && card.visible && message.visible && !editor.visible);
        compare(message.text, "Loading preview…");
        compare([tabs.y, tabs.height, card.y, card.height, panel.detailsItem.headerHeight], geometry);
        tryVerify(() => controller.detailState.requestId.length > 0);
        const obsolete = controller.detailState.requestId;
        detailsReply(controller, entries[1]);
        compare(editor.text, "second");
        calls = [];

        keyClick(Qt.Key_Up);
        compare(controller.detailState.value.entry.id, "first", "cache hit paints in the selection turn");
        verify(!controller.detailState.loading && editor.visible && !message.visible);
        compare([tabs.y, tabs.height, card.y, card.height, panel.detailsItem.headerHeight], geometry);
        // Cancellation/transport filtering is not the only stale-reply guard.
        controller.detailState.applyDetails(obsolete, {entry: entries[1], text: "stale", files: []});
        compare(editor.text, "first");
        keyClick(Qt.Key_Down);
        compare(editor.text, "second");
        keyClick(Qt.Key_Down);
        verify(controller.detailState.loading);
        keyClick(Qt.Key_Up);
        compare(editor.text, "second");
        wait(100);
        compare(previewCalls().length, 0, "rapid uncached crossing is still debounced");
        verify(!calls.some(call => call.route.localId.indexOf("edit-") === 0));
        keyClick(Qt.Key_C, Qt.AltModifier);
        tryVerify(() => calls.some(call => call.route.localId === "action-copy"));
        const action = calls.find(call => call.route.localId === "action-copy");
        compare(action.params.entry_id, "second", "warm preview never redirects an action");
    }

    function test_imageRepliesKeepChromeAndDoNotReportUnavailableWhilePending_data() {
        return [{tag: "details-first", thumbnailFirst: false}, {tag: "thumbnail-first", thumbnailFirst: true}];
    }
    function test_imageRepliesKeepChromeAndDoNotReportUnavailableWhilePending(data) {
        const entries = [entry("first", "image"), entry("second", "image")];
        const controller = makeController(entries);
        const panel = makePanel(controller);
        const tabs = findChild(panel, "clipboardDetailsTabs");
        const card = findChild(panel, "clipboardDataCard");
        const message = findChild(panel, "clipboardPreviewMessage");
        const image = findChild(panel, "clipboardThumbnail");
        const headerHeight = panel.detailsItem.headerHeight;
        compare(panel.detailsItem.secondaryActions.filter(action => action.visible).length, 3);
        verify(panel.detailsItem.secondaryActions.every(action => !action.enabled));
        keyClick(Qt.Key_E, Qt.AltModifier);
        verify(!calls.some(call => call.route.localId === "action-annotate"));
        if (data.thumbnailFirst) {
            thumbnailReply(controller, entries[0]);
            verify(message.visible);
            compare(message.text, "Loading preview…");
            compare(controller.detailState.previewCache.length, 0);
            detailsReply(controller, entries[0], null);
        } else {
            detailsReply(controller, entries[0], null);
            verify(message.visible);
            compare(message.text, "Loading preview…");
            compare(controller.detailState.previewCache.length, 0);
            thumbnailReply(controller, entries[0]);
        }
        tryCompare(image, "status", Image.Ready);
        verify(image.visible && !message.visible);
        compare(controller.detailState.previewCache.length, 1);
        compare(panel.detailsItem.headerHeight, headerHeight);
        keyClick(Qt.Key_Down);
        verify(tabs.visible && card.visible && message.visible && !image.visible);
        compare(panel.detailsItem.headerHeight, headerHeight);
        detailsReply(controller, entries[1], null);
        controller.detailState.handleFailure(controller.detailState.thumbnailRequestId, "Thumbnail failed");
        verify(message.visible);
        compare(message.text, "Image preview is unavailable");
        calls = [];
        keyClick(Qt.Key_Up);
        tryCompare(image, "status", Image.Ready);
        verify(!message.visible && image.visible);
        compare(previewCalls().length, 0);
    }

    function test_cacheBoundsRevisionAndFailedDraftPriority() {
        const entries = [];
        for (let i = 0; i < 14; i++)
            entries.push(entry("row-" + i));
        const controller = makeController(entries);
        controller.openDetails();
        for (let i = 0; i < 12; i++) {
            controller.select(i);
            controller.detailState.load();
            detailsReply(controller, entries[i]);
        }
        const state = controller.detailState;
        compare(state.previewCache.length, state.previewCacheLimit);
        controller.select(0); // Touch the oldest entry: row-1 should now be evicted.
        compare(state.value.entry.id, "row-0");
        controller.select(12);
        state.load();
        detailsReply(controller, entries[12]);
        verify(state.cachedPreview(entries[0]) !== null);
        compare(state.cachedPreview(entries[1]), null);
        compare(state.cachedPreview(entry("row-0", "text", 2)), null);
        controller.select(13);
        state.load();
        detailsReply(controller, entries[13], "x".repeat(state.previewCacheByteLimit));
        compare(state.cachedPreview(entries[13]), null, "oversized payloads remain visible but are not retained");
        verify(state.previewCacheBytes <= state.previewCacheByteLimit);
        state.clearCache();
        for (let i = 0; i < 4; i++) {
            controller.select(i);
            state.load();
            detailsReply(controller, entries[i], "x".repeat(400000));
        }
        verify(state.previewCache.length < 4, "byte budget evicts before the entry-count limit");
        verify(state.previewCacheBytes <= state.previewCacheByteLimit);

        state.failedDrafts[entries[3].id] = {target: entries[3], preview: state.value, draft: "Unsaved", error: "Conflict", direct: true};
        controller.select(2);
        controller.select(3);
        verify(state.editing && state.editDirty);
        compare(state.editDraft, "Unsaved", "a cached acknowledged value cannot replace a failed draft");
        compare(state.editError, "Conflict");
    }

    function test_revisionAndLateThumbnailCannotReuseOldPreview() {
        const entries = [entry("first", "image"), entry("second", "image")];
        const controller = makeController(entries);
        controller.openDetails();
        const staleDetails = controller.detailState.requestId;
        const staleThumbnail = controller.detailState.thumbnailRequestId;
        controller.select(1);
        controller.detailState.load();
        const currentDetails = controller.detailState.requestId;
        const currentThumbnail = controller.detailState.thumbnailRequestId;
        controller.detailState.applyDetails(staleDetails, {entry: entries[0], text: null, files: []});
        controller.detailState.applyThumbnail(staleThumbnail, {entry_id: "first", revision: 1, path: "/stale"});
        compare(controller.detailState.requestId, currentDetails);
        compare(controller.detailState.thumbnailRequestId, currentThumbnail);
        compare(controller.detailState.previewCache.length, 0);
        detailsReply(controller, entries[1], null);
        thumbnailReply(controller, entries[1]);
        compare(controller.detailState.previewCache.length, 1);
        const revised = entry("second", "image", 2);
        controller.replaceProviderResults(controller.provider.resultsForEntries([entries[0], revised]), false);
        compare(controller.selectedEntry.id, "second");
        verify(controller.detailState.loading);
        compare(controller.detailState.value, null);
        compare(controller.detailState.thumbnail, null);
        controller.detailState.load();
        detailsReply(controller, revised, null);
        thumbnailReply(controller, revised);
        compare(controller.detailState.value.entry.revision, 2);
        compare(controller.detailState.cachedPreview(entries[1]), null);
    }

    function test_privateModeDoesNotRetainNewReads() {
        const entries = [entry("first"), entry("second")];
        const controller = makeController(entries);
        controller.applyCapture({private_mode: true});
        controller.openDetails();
        detailsReply(controller, entries[0]);
        compare(controller.detailState.previewCache.length, 0);
        controller.select(1);
        controller.detailState.load();
        detailsReply(controller, entries[1]);
        compare(controller.detailState.previewCache.length, 0);
        controller.select(0);
        verify(controller.detailState.loading, "private reads are not warm-cache hits");
        controller.detailState.load();
        controller.applySettings({private_mode: false});
        detailsReply(controller, entries[0]);
        compare(controller.detailState.previewCache.length, 0, "a privacy boundary fences reads already in flight");
    }

    function test_cacheInvalidation_data() {
        // Sample revision, privacy and invocation boundaries rather than each
        // mutation callback that delegates to the same invalidation path.
        return ["history", "privacy", "hide"].map(boundary => ({tag: boundary, boundary: boundary}));
    }
    function test_cacheInvalidation(data) {
        const entries = [entry("first"), entry("second")];
        const controller = makeController(entries);
        controller.openDetails();
        detailsReply(controller, entries[0]);
        compare(controller.detailState.previewCache.length, 1);
        controller.select(1);
        controller.detailState.load();
        const pending = controller.detailState.requestId;
        switch (data.boundary) {
        case "history": controller.handleHistoryChanged("new-revision"); break;
        case "privacy": controller.applySettings({private_mode: true}); break;
        case "hide": controller.deactivateUi(); break;
        }
        compare(controller.detailState.previewCache.length, 0);
        controller.detailState.applyDetails(pending, {entry: entries[1], text: "late", files: []});
        compare(controller.detailState.previewCache.length, 0, "pre-invalidation replies cannot refill the cache");
    }
}
