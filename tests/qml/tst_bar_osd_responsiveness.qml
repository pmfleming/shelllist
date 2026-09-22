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
        Quickshell.environment = {
            SHELLLIST_NO_ANIMATIONS: "0"
        };
        compare(Ui.Theme.noAnimations, false);
    }

    function cleanup() {
        Quickshell.environment = ({});
    }

    function makePanel() {
        const panel = createTemporaryObject(osdComponent, testCase);
        verify(panel !== null);
        // The frame is internal to Shelllist.Bar; load its file without making
        // it public just to expose it to tests.
        const component = Qt.createComponent("../../qml/Shelllist/Bar/BarOsdContent.qml");
        compare(component.status, Component.Ready, component.errorString());
        panel.surface = createTemporaryObject(component, panel, {
            controller: panel.controller,
            width: panel.width,
            height: panel.height
        });
        verify(panel.surface !== null);
        verify(waitForRendering(panel));
        return panel;
    }

    function test_suspendTelemetryKeepsResumeAndOsdRouting() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.applySnapshot({ power_sleep: { available: true, inhibitors: [], resume_generation: 2 } });
        compare(controller.powerSuspend.resume_generation, 2);
        controller.handleEvent({ event: "changed", stream: "power-sleep.changed", data: {
            available: true, inhibitors: [{ what: "idle", mode: "block" }], resume_generation: 3
        } });
        compare(controller.powerSuspend.resume_generation, 3);
        compare(controller.osd.kind, "idle-inhibitor");
        compare(controller.osd.valueLabel, "Active");
    }

    function test_progressTracksEveryConfirmedValueImmediately() {
        const panel = makePanel();
        const fill = findChild(panel, "osdProgressFill");
        const thumb = findChild(panel, "osdProgressThumb");
        verify(fill !== null && thumb !== null);
        for (const percent of [20, 80, 35, 90, 0, 100, 50]) {
            panel.controller.showBrightnessOsd({
                available: true,
                percent: percent
            });
            compare(panel.surface.opacity, 1, "first feedback must not fade in");
            fuzzyCompare(fill.width, fill.parent.width * percent / 100, 0.01, "progress must not wait for an animation or chase key repeats");
            fuzzyCompare(thumb.x, Math.max(0, Math.min(fill.parent.width - thumb.width, fill.width - thumb.width / 2)), 0.01, "thumb and fill must agree in the same frame");
        }
    }

    function test_brightnessFailure_data() {
        return [
            { tag: "backend", kind: "backend" },
            { tag: "response-transport", kind: "response-transport" },
            { tag: "send", kind: "send" },
            { tag: "lost-pending-request", kind: "lost-pending-request" }
        ];
    }

    function test_brightnessFailure(data) {
        const panel = makePanel();
        const controller = panel.controller;
        controller.brightness = { available: true, percent: 65 };
        controller.showBrightnessOsd(controller.brightness);
        const backend = controller.backend;
        const id = "brightness-adjust-1";
        if (data.kind === "backend") {
            backend.finish(id, {
                protocol: "bar-api", version: 1, ok: false,
                error: { code: "brightness-operation-failed", message: "Permission denied" }
            }, "");
        } else if (data.kind === "response-transport") {
            backend.finish(id, {}, "Transport lost");
        } else if (data.kind === "send") {
            backend.sendFailed(id, "Not connected");
        } else {
            backend.setPending(id, true);
            backend.failTransport("Transport lost");
        }
        compare(controller.osdVisible, true);
        compare(controller.osd.kind, "brightness-error");
        compare(controller.osd.valueLabel, "Adjustment failed");
        compare(controller.osd.progressVisible, false);
        compare(controller.osd.timeoutMs, 3000);
        compare(controller.brightness.percent, 65, "failure must preserve confirmed state");
        backend.finish("brightness-adjust-2", {
            protocol: "bar-api", version: 1, ok: true,
            data: { brightness: { available: true, percent: 70 } }
        }, "");
        compare(controller.osd.kind, "brightness");
        compare(controller.osd.valueLabel, "70%");
        compare(controller.osd.progressVisible, true);
    }

    function test_unrelatedFailuresDoNotShowBrightnessError() {
        const panel = makePanel();
        panel.controller.osdVisible = false;
        panel.controller.backend.finish("snapshot-1", {}, "Transport lost");
        panel.controller.backend.sendFailed("audio-adjust-1", "Not connected");
        panel.controller.backend.transportFailed("Transport lost", ["snapshot-2"]);
        compare(panel.controller.osdVisible, false);
    }

    function test_reopeningDuringDismissalIsImmediate() {
        const panel = makePanel();
        panel.controller.showBrightnessOsd({
            available: true,
            percent: 20
        });
        panel.controller.osdVisible = false;
        wait(30);
        panel.controller.showBrightnessOsd({
            available: true,
            percent: 80
        });
        compare(panel.surface.opacity, 1);
        const fill = findChild(panel, "osdProgressFill");
        fuzzyCompare(fill.width, fill.parent.width * 0.8, 0.01);
    }
}
