pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Bar as Bar
import "../../bar/BarMediaPresentation.js" as Media

TestCase {
    id: testCase
    name: "BarOsdResponsiveness"
    when: windowShown
    Component {
        id: controllerFactory
        Bar.BarController {
            surfaceRegistry: null
            backend.active: false
        }
    }
    // Negative RPC outcomes log application warnings; engine errors still fail.
    function init() { failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/); }
    function test_mediaTransport() {
        for (const [mode, type, operations] of [["tracks", "video", ["previous", "next"]], ["automatic", "music", ["previous", "next"]], ["automatic", "video", ["seek", "seek"]], ["seek", "music", ["seek", "seek"]]]) {
            for (const forward of [false, true]) for (const allowed of [false, true]) {
                const player = {control_mode: mode, content_type: type, can_control: true, can_next: allowed, can_previous: allowed, can_seek: allowed};
                const action = Media.transportAction(player, forward);
                compare(action.operation, operations[Number(forward)]);
                compare(action.offset, forward ? 30 : -30);
                compare(action.enabled, allowed);
                verify(action.label.length > 0 && action.icon.length > 0);
                player.can_control = false;
                verify(!Media.transportAction(player, forward).enabled);
            }
        }
        verify(!Media.transportAction(null, true).enabled);
    }
    function test_brightnessFailure_data() {
        return [{tag: "rejected", disconnected: false}, {tag: "lost-pending-request", disconnected: true}];
    }
    function test_brightnessFailure(data) {
        const controller = createTemporaryObject(controllerFactory, testCase);
        controller.brightness = {available: true, percent: 65};
        controller.showBrightnessOsd(controller.brightness);
        const backend = controller.backend;
        const id = "brightness-adjust-1";
        if (data.disconnected) {
            backend.setPending(id, true);
            backend.failSharedTransport("Transport lost");
        } else {
            backend.finish(id, {
                protocol: "bar-api", version: 1, ok: false,
                error: {code: "brightness-operation-failed", message: "Permission denied"}
            }, "");
        }
        verify(controller.osdVisible);
        compare(controller.osd.kind, "brightness-error");
        verify(!controller.osd.progressVisible);
        compare(controller.brightness.percent, 65, "failure cannot replace acknowledged brightness");
        backend.finish("brightness-adjust-2", {
            protocol: "bar-api", version: 1, ok: true,
            data: {brightness: {available: true, percent: 70}}
        }, "");
        compare(controller.osd.kind, "brightness");
        verify(controller.osd.progressVisible);
        compare(controller.brightness.percent, 70);
    }
}
