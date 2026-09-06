pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Shelllist.Bar as Bar
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "BarOsdResponsiveness"
    when: windowShown
    visible: true
    width: 376
    height: 104

    Component {
        id: osdComponent
        Item {
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            property var surface
            Bar.BarController {
                id: controller
                surfaceRegistry: null
                backend.active: false
            }
        }
    }

    function init() {
        // Exercise the normal animated theme, not the headless no-motion default.
        Quickshell.environment = { SHELLLIST_NO_ANIMATIONS: "0" };
        compare(Ui.Theme.noAnimations, false);
    }

    function cleanup() { Quickshell.environment = ({}); }

    function makePanel() {
        const panel = createTemporaryObject(osdComponent, testCase);
        verify(panel !== null);
        // The frame is internal to Shelllist.Bar; load its file without making
        // it public just to expose it to tests.
        const component = Qt.createComponent("../../qml/Shelllist/Bar/BarOsdContent.qml");
        compare(component.status, Component.Ready, component.errorString());
        panel.surface = createTemporaryObject(component, panel, {
            controller: panel.controller, width: panel.width, height: panel.height
        });
        verify(panel.surface !== null);
        verify(waitForRendering(panel));
        return panel;
    }

    function test_progressTracksEveryConfirmedValueImmediately() {
        const panel = makePanel();
        const fill = findChild(panel, "osdProgressFill");
        const thumb = findChild(panel, "osdProgressThumb");
        verify(fill !== null && thumb !== null);
        for (const percent of [20, 80, 35, 90, 0, 100, 50]) {
            panel.controller.showBrightnessOsd({ available: true, percent: percent });
            compare(panel.surface.opacity, 1, "first feedback must not fade in");
            fuzzyCompare(fill.width, fill.parent.width * percent / 100, 0.01,
                "progress must not wait for an animation or chase key repeats");
            fuzzyCompare(thumb.x, Math.max(0, Math.min(fill.parent.width - thumb.width,
                fill.width - thumb.width / 2)), 0.01,
                "thumb and fill must agree in the same frame");
        }
    }

    function test_reopeningDuringDismissalIsImmediate() {
        const panel = makePanel();
        panel.controller.showBrightnessOsd({ available: true, percent: 20 });
        panel.controller.osdVisible = false;
        wait(30);
        panel.controller.showBrightnessOsd({ available: true, percent: 80 });
        compare(panel.surface.opacity, 1);
        const fill = findChild(panel, "osdProgressFill");
        fuzzyCompare(fill.width, fill.parent.width * 0.8, 0.01);
    }
}
