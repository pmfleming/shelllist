pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Bar as Bar

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
    function test_brightnessFailure_data() {
        return [{tag: "lost-pending-request", disconnected: true}];
    }
    function test_brightnessFailure(data) {
        const controller = createTemporaryObject(controllerFactory, testCase);
        controller.brightness = {available: true, percent: 65};
        controller.showBrightnessOsd(controller.brightness);
        const backend = controller.backend;
        const id = "brightness-adjust-1";
        backend.setPending(id, true);
        backend.failSharedTransport("Transport lost");
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
