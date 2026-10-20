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
    Component {
        id: controllerFactory
        Clip.ClipboardController {}
    }
    function init() {
        failOnWarning(/.*/);
        calls = [];
    }
    function cleanup() { wait(0); }
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
    function reply(controller, id, data) {
        findChild(controller, "clipboardBackend").acceptSharedResponse(id, {
            protocol: "clip-api", version: 2, ok: true, data: data
        }, "");
    }
    function detailsReply(controller, target, text) {
        tryVerify(() => controller.detailState.requestId.length > 0);
        reply(controller, controller.detailState.requestId, {
            entry: {entry: target, text: text === undefined ? target.id : text, files: []}
        });
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

}
